# fastladder-pixiv

Post pixiv news to Fastladder.

## Environment variables
- `FASTLADDER_URL` (required)
    - Your Fastladder URL
    - e.g. `https://fastladder.example.com`
- `FASTLADDER_API_KEY` (required)
    - Your Fastladder API key
    - e.g. `0123456789abcdef`
- `REPLACE_URL` (optional)
    - Replace image hosts
    - e.g. `https://fastladder-image-proxy.example.com`
- `PIXIV_USERNAME` (optional)
    - pixiv username for login
    - Required for `bookmark` or `user` subcommnd.
- `PIXIV_PASSWORD` (required)
    - pixiv password for login
    - Required for `bookmark` or `user` subcommnd.
