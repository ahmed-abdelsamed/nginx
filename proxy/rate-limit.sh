To configure rate limiting in NGINX, follow these steps to control request rates and protect your server from abuse:

---

### **1. Define a Rate Limit Zone**
Add a `limit_req_zone` directive in the `http` block of your NGINX configuration (`nginx.conf` or a site-specific file):
```nginx
http {
    # Define a shared memory zone to track request rates
    limit_req_zone $binary_remote_addr zone=ratelimit:10m rate=10r/s;
    # Key: Client IP ($binary_remote_addr)
    # Zone: 'ratelimit' with 10MB memory
    # Rate: 10 requests per second (r/s)
}
```
- **`$binary_remote_addr`**: Uses the client IP for rate limiting.
- **`zone=ratelimit:10m`**: Allocates 10MB of memory (stores ~160,000 IPs).
- **`rate=10r/s`**: Allows 10 requests per second.

---

### **2. Apply Rate Limiting to Specific Routes**
Use `limit_req` in a `server` or `location` block to enforce the limit:
```nginx
server {
    location /api/ {
        # Apply the 'ratelimit' zone
        limit_req zone=ratelimit;
        # Optional: Allow bursts of 20 requests with no delay
        limit_req zone=ratelimit burst=20 nodelay;
        proxy_pass http://backend;
    }
}
```
- **`burst=20`**: Permits 20 excess requests before delaying/rejecting.
- **`nodelay`**: Processes burst requests immediately without delay.

---

### **3. Customize the Error Response**
Override the default `503` status code for rate-limited requests:
```nginx
http {
    limit_req_status 429;  # Return 429 (Too Many Requests)
}
```

---

### **4. Whitelist Trusted IPs**
Exclude specific IPs/subnets from rate limiting using `geo` and `map` blocks:
```nginx
http {
    geo $whitelist {
        default 0;
        192.168.1.0/24 1;  # Trusted subnet
        10.0.0.1 1;         # Trusted IP
    }

    map $whitelist $limit_key {
        0 $binary_remote_addr;  # Apply rate limiting
        1 "";                   # Bypass rate limiting
    }

    limit_req_zone $limit_key zone=ratelimit:10m rate=10r/s;
}
```

---

### **5. Test and Reload NGINX**
1. Validate the configuration:
   ```bash
   sudo nginx -t
   ```
2. Reload NGINX:
   ```bash
   sudo systemctl reload nginx
   ```

---

### **6. Verify with Load Testing**
Use tools like `ab` (Apache Benchmark) to simulate traffic:
```bash
ab -n 100 -c 20 http://your-domain.com/api/
```
Check NGINX logs for rate-limiting behavior:
```bash
tail -f /var/log/nginx/access.log | grep 429
```

---

### **Advanced Configurations**
#### **Multiple Rate Limits**
Apply different limits to different routes:
```nginx
http {
    limit_req_zone $binary_remote_addr zone=api_limit:10m rate=50r/m;  # 50 requests/minute
    limit_req_zone $binary_remote_addr zone=login_limit:10m rate=5r/m; # 5 requests/minute
}

server {
    location /api/ {
        limit_req zone=api_limit burst=10;
        proxy_pass http://backend;
    }

    location /login {
        limit_req zone=login_limit burst=3;
        proxy_pass http://backend;
    }
}
```

#### **Logging Rate-Limited Requests**
Add custom logging for rate-limited requests:
```nginx
http {
    log_format rate_limited '$remote_addr - $status - $request';
    access_log /var/log/nginx/rate_limited.log rate_limited if=$limit_req_status;
}
```

---

### **Troubleshooting**
- **`zone is full` errors**: Increase the zone size (e.g., `20m`).
- **Incorrect IP tracking**: Use `$http_x_forwarded_for` if behind a proxy:
  ```nginx
  limit_req_zone $http_x_forwarded_for zone=ratelimit:10m rate=10r/s;
  ```

---

### **Final Configuration Example**
```nginx
http {
    limit_req_zone $binary_remote_addr zone=ratelimit:10m rate=10r/s;
    limit_req_status 429;

    server {
        listen 80;
        server_name example.com;

        location / {
            limit_req zone=ratelimit burst=20 nodelay;
            proxy_pass http://backend;
        }

        location /static/ {
            # No rate limiting for static assets
            alias /var/www/static/;
        }
    }
}
```

---

By following these steps, you can effectively manage traffic, prevent abuse, and ensure resource availability on your NGINX server. Adjust values based on your traffic patterns and requirements!
