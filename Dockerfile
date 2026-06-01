# Build stage

FROM dart:stable AS build

WORKDIR /app

# Copy dependency files first for better Docker layer caching

COPY pubspec.* ./

RUN dart pub get

# Copy source code

COPY . .

# Generate Dart Frog server files

RUN dart run dart_frog_cli:dart_frog build

# Compile to native executable

RUN dart compile exe .dart_frog/server.dart -o server

# Runtime stage

FROM debian:bullseye-slim

WORKDIR /app

# Install certificates for HTTPS requests

RUN apt-get update 
&& apt-get install -y --no-install-recommends ca-certificates 
&& rm -rf /var/lib/apt/lists/*

# Copy compiled executable

COPY --from=build /app/server ./server

# Railway injects PORT automatically

ENV PORT=8080

EXPOSE 8080

CMD ["./server"]
