# Trivial-RSA

### What is this?

I've set up a bunch of point-to-point [OpenVPN](https://openvpn.net/)
instances, and I like to use TLS in order to get forward secrecy, which
requires a CA and certificates. The canonical software for setting up a
CA to use with OpenVPN is [Easy-RSA](https://github.com/OpenVPN/easy-rsa),
however I find it overkill for a strictly two node point-to-point setup.
Trivial-RSA generates a CA, a key and certificate for the `tls-server`, a
key and certificate for the `tls-client`, Diffie-Hellman parameters, a key
for `tls-auth` or `tls-crypt` and tarballs with config file skeletons. It
asks no questions and deletes the CA key after everything is signed.

### Isn't OpenVPN [insecure](https://blog.trailofbits.com/2016/12/12/meet-algo-the-vpn-that-works/)?

Maybe. My generated configs are for a point-to-point instance and don't
expose the TLS stack to unauthenticated users, so I'm comfortable with
the risk. I take no responsibility for your choice to use OpenVPN or this
script.

### I don't like something about the config parameters.

I probably don't care. I wrote this for my own use, and have posted it
because it may be useful to others. You're free to edit it.

### This was helpful, how can I thank you?

A simple thank you email would be wonderful.
