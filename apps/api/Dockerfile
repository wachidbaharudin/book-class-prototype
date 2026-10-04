# syntax=docker/dockerfile:1
# Production image for the NestJS API (ENG-00 §7).
FROM node:22-alpine AS base
RUN npm install -g pnpm@10.17.1
WORKDIR /workspace

FROM base AS build
# Manifest-only install so the dependency layer is cached independently of source.
COPY pnpm-workspace.yaml package.json pnpm-lock.yaml tsconfig.base.json ./
COPY apps/api/package.json apps/api/
COPY apps/web/package.json apps/web/
COPY packages/shared/package.json packages/shared/
RUN pnpm install --frozen-lockfile

COPY packages/shared packages/shared
COPY apps/api apps/api
RUN pnpm --filter @bookclass/shared build \
 && pnpm --filter @bookclass/api build

FROM base AS runner
ENV NODE_ENV=production
# Production-only, workspace-filtered install for a smaller runtime image.
COPY pnpm-workspace.yaml package.json pnpm-lock.yaml ./
COPY apps/api/package.json apps/api/
COPY packages/shared/package.json packages/shared/
RUN pnpm install --frozen-lockfile --prod --filter "@bookclass/api..." \
 && pnpm store prune

COPY --from=build /workspace/packages/shared/dist packages/shared/dist
COPY --from=build /workspace/apps/api/dist apps/api/dist

EXPOSE 4000
CMD ["node", "apps/api/dist/main.js"]
