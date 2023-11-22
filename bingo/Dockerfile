FROM alpine:3.14

RUN adduser \
  --disabled-password \
  --home "/nonexistent" \
  --shell "/sbin/nologin" \
  --no-create-home \
  bingo

WORKDIR /opt/bingo/

COPY bingo /opt/bingo/
COPY config.yaml /opt/bingo/
COPY start_app.sh /opt/bingo/

RUN mkdir -p /opt/bongo/logs/fa2acf5dcc &&\
 touch /opt/bongo/logs/fa2acf5dcc/main.log &&\
 chown -R bingo:bingo /opt/bongo &&\
 chown -R bingo:bingo /opt/bingo &&\
 chmod +x bingo &&\
 chmod +x start_app.sh

USER bingo:bingo

EXPOSE 30238

#ENTRYPOINT [ "/opt/bingo/bingo", "run_server" ]
ENTRYPOINT ["sh", "./start_app.sh"]
