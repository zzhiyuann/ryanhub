export async function register() {
  if (process.env.NEXT_RUNTIME === "nodejs") {
    const { scanMissingBooks } = await import("@/lib/book-watcher");
    const { startScheduler } = await import("@/lib/book-scheduler");

    const path = await import("path");
    const sourceDir =
      process.env.BOOK_SOURCE_DIR || path.join(process.cwd(), "books");

    // Startup scan: catch up on any books generated outside the server
    const result = scanMissingBooks(sourceDir);
    if (result.imported > 0 || result.repaired > 0) {
      console.log(
        `[Startup] Book scan: ${result.imported} imported, ${result.repaired} repaired (${result.scanned} scanned)`
      );
    }

    // Start the book generation scheduler (replaces launchd)
    startScheduler();
  }
}
