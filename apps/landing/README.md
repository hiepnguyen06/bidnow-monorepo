# BidNow landing

Static showcase site for BidNow: tech stack, architecture and features. It has no backend dependency, so it can stay online after the main app is shut down.

```bash
npm install
npm run dev     # http://localhost:3000
npm run build   # static export to ./out, serve it from any static host
npm run test
```

The architecture content lives in `app/page.tsx` and `lib/about.ts`.
