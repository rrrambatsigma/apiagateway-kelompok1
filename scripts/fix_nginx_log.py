path = r'E:\SMT 5\Desain Aplikasi Big Data\Tugas-APIgateway\apiagateway-kelompok1\gateway\nginx.conf'
with open(path, 'r') as f:
    content = f.read()

old = """    sendfile on;


    # =================================================================
    # RATE LIMITER"""

new_log_format = """    sendfile on;


    # =================================================================
    # ACCESS LOG FORMAT
    # =================================================================

    log_format main escape=json
        '{"time":"$time_iso8601",'
         '"remote_addr":"$remote_addr",'
         '"request":"$request",'
         '"status":$status,'
         '"body_bytes_sent":$body_bytes_sent,'
         '"request_time":$request_time,'
         '"upstream_addr":"$upstream_addr",'
         '"upstream_status":"$upstream_status",'
         '"upstream_response_time":"$upstream_response_time",'
         '"http_referer":"$http_referer",'
         '"http_user_agent":"$http_user_agent"}';

    access_log /dev/stdout main;


    # =================================================================
    # RATE LIMITER"""

content = content.replace(old, new_log_format, 1)

with open(path, 'w') as f:
    f.write(content)
print('SUCCESS: nginx access_log format added')
