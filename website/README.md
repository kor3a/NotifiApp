# React + TypeScript + Vite

This template provides a minimal setup to get React working in Vite with HMR and some ESLint rules.

Currently, two official plugins are available:

- [@vitejs/plugin-react](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react) uses [Oxc](https://oxc.rs)
- [@vitejs/plugin-react-swc](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react-swc) uses [SWC](https://swc.rs/)

## React Compiler

The React Compiler is not enabled on this template because of its impact on dev & build performances. To add it, see [this documentation](https://react.dev/learn/react-compiler/installation).

## Expanding the ESLint configuration

If you are developing a production application, we recommend updating the configuration to enable type-aware lint rules:

```js
export default defineConfig([
  globalIgnores(['dist']),
  {
    files: ['**/*.{ts,tsx}'],
    extends: [
      // Other configs...

      // Remove tseslint.configs.recommended and replace with this
      tseslint.configs.recommendedTypeChecked,
      // Alternatively, use this for stricter rules
      tseslint.configs.strictTypeChecked,
      // Optionally, add this for stylistic rules
      tseslint.configs.stylisticTypeChecked,

      // Other configs...
    ],
    languageOptions: {
      parserOptions: {
        project: ['./tsconfig.node.json', './tsconfig.app.json'],
        tsconfigRootDir: import.meta.dirname,
      },
      // other options...
    },
  },
])
```

You can also install [eslint-plugin-react-x](https://github.com/Rel1cx/eslint-react/tree/main/packages/plugins/eslint-plugin-react-x) and [eslint-plugin-react-dom](https://github.com/Rel1cx/eslint-react/tree/main/packages/plugins/eslint-plugin-react-dom) for React-specific lint rules:

```js
// eslint.config.js
import reactX from 'eslint-plugin-react-x'
import reactDom from 'eslint-plugin-react-dom'

export default defineConfig([
  globalIgnores(['dist']),
  {
    files: ['**/*.{ts,tsx}'],
    extends: [
      // Other configs...
      // Enable lint rules for React
      reactX.configs['recommended-typescript'],
      // Enable lint rules for React DOM
      reactDom.configs.recommended,
    ],
    languageOptions: {
      parserOptions: {
        project: ['./tsconfig.node.json', './tsconfig.app.json'],
        tsconfigRootDir: import.meta.dirname,
      },
      // other options...
    },
  },
])
```

## Build for AWS S3 + CloudFront

This project is configured to output production files into `out/`.

1. Build:

```bash
npm install
npm run build
```

2. Upload the contents of `out/` to your S3 bucket (not the folder itself, the files inside it).
### Current production setup (nearbuyallim.com)

This site is **not** a single-page app — it ships two real, separate pages:
`/index.html` (homepage) and `/verify/index.html` (the email-verification
landing page). Because of that, the usual SPA "map every 403/404 to
`/index.html`" trick is **wrong here** — it would serve the homepage when
someone visits `/verify`.

- **S3 bucket** `nearbuyallim.com` (region `us-east-1`), kept **private**
  and served through CloudFront via Origin Access Control (OAC). The
  CloudFront origin is the S3 **REST** endpoint
  (`nearbuyallim.com.s3.us-east-1.amazonaws.com`).
- **CloudFront** distribution `E1MCDD8F88E6T8`
  - Default root object: `index.html`
  - **Viewer-request function** `rewrite-index` (see
    [`cloudfront-function.js`](./cloudfront-function.js)) that appends
    `index.html` to directory-style URLs so `/verify/` resolves to
    `/verify/index.html`. The REST origin does not do this on its own; the
    S3 *website* endpoint would, but that requires a public bucket.

After changing files in the bucket, invalidate the edge cache (the
`deploy.sh` script does this automatically):

```bash
aws cloudfront create-invalidation --distribution-id E1MCDD8F88E6T8 --paths "/*"
```

### Generic S3 + CloudFront notes (for a pure SPA)

If you ever convert this to a true client-side-routed SPA, the simpler
config is S3 static website hosting (index + error document both
`index.html`) or CloudFront custom error responses mapping `403`/`404` to
`/index.html` with response code `200`.
