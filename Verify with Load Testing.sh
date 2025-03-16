# Test limit rate
ab -n 100 -c 20 http://your-domain.com/api/
tail -f /var/log/nginx/access.log | grep 429
