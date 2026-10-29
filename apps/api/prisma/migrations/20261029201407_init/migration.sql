-- CreateTable
CREATE TABLE "Article" (
    "id" TEXT NOT NULL,
    "videoUrl" TEXT NOT NULL,
    "images" TEXT[],
    "idTitle" TEXT NOT NULL,
    "idMeta" TEXT NOT NULL,
    "idBody" TEXT NOT NULL,
    "enTitle" TEXT NOT NULL,
    "enMeta" TEXT NOT NULL,
    "enBody" TEXT NOT NULL,
    "jsonLd" JSONB NOT NULL,
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
    "articleId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Job_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Job_articleId_key" ON "Job"("articleId");

-- AddForeignKey
ALTER TABLE "Job" ADD CONSTRAINT "Job_articleId_fkey" FOREIGN KEY ("articleId") REFERENCES "Article"("id") ON DELETE SET NULL ON UPDATE CASCADE;
