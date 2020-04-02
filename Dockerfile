FROM --platform=$BUILDPLATFORM golang:alpine AS build
ARG TARGETPLATFORM
ARG BUILDPLATFORM
RUN echo "I am running on $BUILDPLATFORM, building for $TARGETPLATFORM" | tee  /log
RUN export | sort
RUN ip a
RUN ip r
RUN sleep 30
FROM alpine
COPY --from=build /log /log
