A collection of templates for Void Linux, to be used with xbps-src.

To add repository:

```
# echo 'repository=https://zunixorn.github.io/void-templates/$LIBC' > /etc/xbps.d/11-mytemplates.conf
```

> where $LIBC is either musl or glibc

`ssh-keygen -t rsa -b 4096 -m PEM -f privkey.pem`
