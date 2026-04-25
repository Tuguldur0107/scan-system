FROM dart:stable AS build

WORKDIR /app
COPY packages/shared /app/packages/shared
COPY server /app/server

WORKDIR /app/server
RUN dart pub get
RUN dart pub global activate dart_frog_cli
RUN dart pub global run dart_frog_cli:dart_frog build
RUN dart compile exe build/bin/server.dart -o bin/server

FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/server/bin/server /app/bin/server

EXPOSE 8080
ENTRYPOINT ["/app/bin/server"]
