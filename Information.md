 backend:

docker compose down -v
docker compose up --build -d
docker compose ps

 flutter:
flutter build web --release
docker compose up --build -d
docker compose ps


  web:
    build: ./frontend_manga
    container_name: manga_web
    ports:
      - "8080:80"
    depends_on:
      - api

code ini coment dulu saat di backend dan uncomment code saat sebelum build di flutter