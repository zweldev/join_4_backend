FROM dart:stable AS build

WORKDIR /app

COPY pubspec.* ./
RUN dart pub get

COPY . .

RUN dart run dart_frog_cli:dart_frog build
RUN dart compile exe .dart_frog/server.dart -o server

FROM debian:bullseye-slim

WORKDIR /app

RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

COPY --from=build /app/server ./server

ENV PORT=8080

EXPOSE 8080

CMD ["./server"]