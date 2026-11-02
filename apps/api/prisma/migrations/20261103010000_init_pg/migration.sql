-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateTable
CREATE TABLE "Article" (
    "id" TEXT NOT NULL,
    "videoUrl" TEXT NOT NULL,
    "creator" TEXT,
    "images" TEXT NOT NULL DEFAULT '[]',
    "idTitle" TEXT NOT NULL,
    "idMeta" TEXT NOT NULL,
    "idBody" TEXT NOT NULL,
    "enTitle" TEXT NOT NULL,
    "enMeta" TEXT NOT NULL,
    "enBody" TEXT NOT NULL,
    "jsonLd" TEXT NOT NULL DEFAULT '{}',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Article_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Job" (
    "id" TEXT NOT NULL,
    "url" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'queued',
    "error" TEXT,
    "creator" TEXT,
    "articleId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Job_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Vote" (
    "id" TEXT NOT NULL,
    "articleId" TEXT NOT NULL,
    "value" INTEGER NOT NULL,
    "voterKey" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Vote_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Job_articleId_key" ON "Job"("articleId");

-- CreateIndex
CREATE INDEX "Vote_articleId_idx" ON "Vote"("articleId");

-- CreateIndex
CREATE UNIQUE INDEX "Vote_articleId_voterKey_key" ON "Vote"("articleId", "voterKey");

-- AddForeignKey
ALTER TABLE "Job" ADD CONSTRAINT "Job_articleId_fkey" FOREIGN KEY ("articleId") REFERENCES "Article"("id") ON DELETE SET NULL ON UPDATE CASCADE;

