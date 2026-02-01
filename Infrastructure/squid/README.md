# create new user

```
docker run --rm -it \
  -v $(pwd)/auth:/auth \
  httpd:2.4 \
  htpasswd -bc /auth/passwd user1 strongpass
```

# run 
`docker compose up -d`


# test/use
```
curl -v --proxy http://user1:strongpass@localhost:3128 http://example.com
```

