# syntax=docker/dockerfile:1
# Production image for the Next.js web app (ENG-00 §7). Relies on
# `output: 'standalone'` in next.config.ts to ship a self-contained server.
FROM node:22-alpine AS base
RUN npm install -g pnpm@10.17.1
WORKDIR /workspace

FROM base AS build
COPY pnpm-workspace.yaml package.json pnpm-lock.yaml tsconfig.base.json ./
COPY apps/web/package.json apps/web/
COPY apps/api/package.json apps/api/
COPY packages/shared/package.json packages/shared/
RUN pnpm install --frozen-lockfile

COPY packages/shared packages/shared
COPY apps/web apps/web
RUN pnpm --filter @bookclass/shared build \
 && pnpm --filter @bookclass/web build

FROM node:22-alpine AS runner
ENV NODE_ENV=production
WORKDIR /app

COPY --from=build /workspace/apps/web/.next/standalone ./
COPY --from=build /workspace/apps/web/.next/static ./apps/web/.next/static
COPY --from=build /workspace/apps/web/public ./apps/web/public

ENV HOSTNAME=0.0.0.0
ENV PORT=3000
EXPOSE 3000
CMD ["node", "apps/web/server.js"]
