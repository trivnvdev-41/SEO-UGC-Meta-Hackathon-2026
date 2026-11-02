-- CreateTable
CREATE TABLE "Vote" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "articleId" TEXT NOT NULL,
    "value" INTEGER NOT NULL,
    "voterKey" TEXT NOT NULL,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- CreateIndex
CREATE INDEX "Vote_articleId_idx" ON "Vote"("articleId");

-- CreateIndex
CREATE UNIQUE INDEX "Vote_articleId_voterKey_key" ON "Vote"("articleId", "voterKey");
