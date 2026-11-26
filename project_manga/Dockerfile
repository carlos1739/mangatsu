FROM nginx:alpine
COPY build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 8080
USER 1001
ENTRYPOINT ["sh", "-c", "until nslookup api >/dev/null 2>&1; do echo 'Waiting for API service DNS'; sleep 2; done; exec nginx -g 'daemon off;'"]
