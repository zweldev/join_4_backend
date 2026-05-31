# Build stage
FROM dart:stable AS build
WORKDIR /app

# Copy pubspec files and get dependencies
COPY pubspec.* ./
RUN dart pub get

# Copy the rest of the sources
COPY . ./

# Compile the Dart Frog generated server to a native executable
RUN dart compile exe .dart_frog/server.dart -o /app/bin/server

# Runtime stage
FROM debian:bullseye-slim
WORKDIR /app

# Minimal runtime deps
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates \
  && rm -rf /var/lib/apt/lists/*

# Copy compiled binary from build stage
COPY --from=build /app/bin/server /app/bin/server

# Railway provides the PORT environment variable; default to 8080 for local
ENV PORT=8080

EXPOSE 8080

CMD ["/app/bin/server"]
