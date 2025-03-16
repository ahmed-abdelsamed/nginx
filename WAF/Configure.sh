Configuring **NGINX as a Web Application Firewall (WAF)** involves leveraging modules like **ModSecurity** or **NAXSI** to filter malicious traffic, block attacks (e.g., SQLi, XSS), and enforce security policies. Below is a detailed guide:

---

### **Option 1: Using ModSecurity (OWASP Core Rule Set)**
ModSecurity is a robust WAF engine integrated into NGINX via the `libmodsecurity` module.

#### **Step 1: Install ModSecurity and NGINX**
1. **Install Dependencies** (Ubuntu/Debian):
   ```bash
   sudo apt-get install -y git build-essential libpcre3 libpcre3-dev zlib1g zlib1g-dev libssl-dev libxml2-dev libgeoip-dev libyajl-dev
   ```

2. **Compile NGINX with ModSecurity**:
   ```bash
   # Clone ModSecurity v3 (libmodsecurity)
   git clone --depth 1 -b v3/master --single-branch https://github.com/SpiderLabs/ModSecurity
   cd ModSecurity && git submodule init && git submodule update
   ./build.sh && ./configure && make && sudo make install

   # Download NGINX source
   wget https://nginx.org/download/nginx-1.25.3.tar.gz
   tar -xvzf nginx-1.25.3.tar.gz
   cd nginx-1.25.3

   # Compile NGINX with ModSecurity
   ./configure --add-module=/path/to/ModSecurity-nginx \
     --with-http_ssl_module \
     --with-http_realip_module
   make && sudo make install
   ```

#### **Step 2: Configure ModSecurity Rules**
1. **Download OWASP Core Rule Set (CRS)**:
   ```bash
   git clone https://github.com/coreruleset/coreruleset /etc/nginx/modsec/crs
   cp /etc/nginx/modsec/crs/crs-setup.conf.example /etc/nginx/modsec/crs-setup.conf
   ```

2. **Configure ModSecurity in NGINX**:
   ```nginx
   # /etc/nginx/nginx.conf
   load_module modules/ngx_http_modsecurity_module.so;

   http {
       modsecurity on;
       modsecurity_rules_file /etc/nginx/modsec/main.conf;
   }
   ```

3. **Create `/etc/nginx/modsec/main.conf`**:
   ```nginx
   # Include ModSecurity configuration
   Include /etc/nginx/modsec/modsecurity.conf
   # Include OWASP CRS rules
   Include /etc/nginx/modsec/crs/crs-setup.conf
   Include /etc/nginx/modsec/crs/rules/*.conf
   ```

#### **Step 3: Tune Rules and Whitelist False Positives**
- Disable noisy rules in `/etc/nginx/modsec/crs/rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf`:
  ```nginx
  SecRuleRemoveById 942100   # Example: Disable rule ID 942100
  ```

#### **Step 4: Test and Reload NGINX**
```bash
sudo nginx -t && sudo nginx -s reload
```

---

### **Option 2: Using NAXSI (NGINX Anti-XSS & SQL Injection)**
NAXSI is a lightweight WAF module for NGINX that uses a whitelist-based approach.

#### **Step 1: Install NAXSI**
1. **Install NAXSI Module** (Ubuntu/Debian):
   ```bash
   sudo apt-get install -y nginx-module-naxsi
   ```

2. **Enable NAXSI in NGINX**:
   ```nginx
   # /etc/nginx/nginx.conf
   load_module modules/ngx_http_naxsi_module.so;
   ```

#### **Step 2: Configure NAXSI Rules**
1. **Basic Configuration**:
   ```nginx
   # /etc/nginx/naxsi.rules
   LearningMode;
   SecRulesEnabled;
   DeniedUrl "/naxsi_denied";  # Custom denied page

   # Main rules (whitelist)
   include /etc/nginx/naxsi_core.rules;
   ```

2. **Define Whitelists**:
   ```nginx
   # /etc/nginx/sites-enabled/your-site.conf
   server {
       location / {
           # Enable NAXSI
           include /etc/nginx/naxsi.rules;

           # Whitelist example for a login form
           BasicRule wl:1000 "mz:$ARGS_VAR:username|$ARGS_VAR:password";
           proxy_pass http://backend;
       }

       location /naxsi_denied {
           return 403;  # Custom block response
       }
   }
   ```

---

### **Common WAF Features for Both Options**
#### **1. Block Common Attacks**
- **SQL Injection**:
  ```nginx
  # ModSecurity Rule
  SecRule ARGS "@detectSQLi" "id:1000,deny,status:403,msg:'SQLi Attack'"
  ```
- **Cross-Site Scripting (XSS)**:
  ```nginx
  # NAXSI Rule
  MainRule "str:<script>" "msg:XSS detected" "mz:ARGS|BODY" "s:$XSS:4" id:1001;
  ```

#### **2. Rate Limiting**
```nginx
http {
    limit_req_zone $binary_remote_addr zone=api_limit:10m rate=100r/m;
    limit_req_status 429;
}

server {
    location /api {
        limit_req zone=api_limit burst=50;
        proxy_pass http://backend;
    }
}
```

#### **3. Security Headers**
```nginx
server {
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header Content-Security-Policy "default-src 'self'";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
}
```

#### **4. Block Bad Bots**
```nginx
map $http_user_agent $bad_bot {
    default 0;
    ~*(bot|crawler|spider) 1;
}

server {
    if ($bad_bot) {
        return 403;
    }
}
```

---

### **Testing the WAF**
1. **Test SQLi**:
   ```bash
   curl "http://example.com/?id=1' OR 1=1--"
   ```
   Expected: `403 Forbidden`.

2. **Test XSS**:
   ```bash
   curl "http://example.com/?q=<script>alert(1)</script>"
   ```
   Expected: Blocked by NAXSI/ModSecurity.

3. **Check Logs**:
   ```bash
   tail -f /var/log/nginx/error.log | grep ModSecurity
   ```

---

### **Monitoring and Maintenance**
- **Fail2Ban**: Block IPs with repeated violations:
  ```ini
  # /etc/fail2ban/jail.d/nginx-modsecurity.conf
  [nginx-modsecurity]
  enabled = true
  filter = nginx-modsecurity
  action = iptables-allports[name=nginx_modsec]
  logpath = /var/log/nginx/error.log
  ```
- **Automate Updates**: Regularly update OWASP CRS or NAXSI rules.

---

### **Final Notes**
- **Performance**: ModSecurity adds overhead; use caching and optimize rules.
- **False Positives**: Continuously tune whitelists using audit logs (`/var/log/modsec_audit.log`).
- **Commercial Alternatives**: Consider Cloudflare, AWS WAF, or NGINX App Protect for enterprise needs.

By following these steps, NGINX will act as a robust WAF, protecting against common web threats.
