# Build stage

FROM dart:stable AS build

WORKDIR /app

# Install Dart Frog CLI explicitly (important for CI)

RUN dart pub global activate dart_frog_cli

ENV PATH="/root/.pub-cache/bin:$PATH"

# Copy dependencies first

COPY pubspec.* ./
RUN dart pub get

# Copy full project

COPY . .

# Build production server

RUN dart_frog build

# Compile NEW output location (IMPORTANT FIX)

RUN dart compile exe build/bin/server.dart -o server

# Runtime stage

FROM debian:bullseye-slim

WORKDIR /app

RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

COPY --from=build /app/server ./server

ENV PORT=8080
EXPOSE 8080

CMD ["./server"]
