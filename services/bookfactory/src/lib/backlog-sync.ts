import * as fs from "fs";
import * as path from "path";
import { getDb } from "@/lib/db";

const BACKLOG_PATH = process.env.BACKLOG_PATH || path.join(process.cwd(), "books", "topic_backlog.md");

interface QueueTopic {
  id: string;
  user_id: string;
  tier: string | null;
  title: string;
  description: string | null;
  status: string;
  position: number;
  generated_date: string | null;
  generated_slot: string | null;
}

/**
 * Regenerate topic_backlog.md from the current database state.
 * Preserves the markdown structure with proper tier groupings.
 */
export function writeBacklogToFile(userId: string): void {
  const db = getDb();
  const topics = db
    .prepare(`SELECT * FROM queue_topics WHERE user_id = ? ORDER BY position ASC`)
    .all(userId) as QueueTopic[];

  // Group topics by tier
  const grouped = new Map<string, QueueTopic[]>();
  for (const t of topics) {
    const tier = t.tier || "Uncategorized";
    if (!grouped.has(tier)) grouped.set(tier, []);
    grouped.get(tier)!.push(t);
  }

  // Define tier ordering and display names
  const tierOrder = [
    "Tier 1", "Tier 2", "Tier 3", "Tier 4", "Tier 5",
    "Tier 6", "Tier 7", "Tier 8", "Tier 9", "Tier 10",
    "Tier L1", "Tier L2", "Tier L3", "Tier L4", "Tier L5",
    "Tier L6", "Tier L7", "Tier L8", "Tier L9", "Tier L10",
    "Tier L11", "Tier L12",
  ];

  const tierNames: Record<string, string> = {
    "Tier 1": "Behavioral Science Foundations",
    "Tier 2": "Cognitive Psychology for Behavioral AI",
    "Tier 3": "Intervention Design & Applied Behavior Change",
    "Tier 4": "Causal Inference & Experimentation",
    "Tier 5": "Measurement Science",
    "Tier 6": "Multimodal Sensing & Signal",
    "Tier 7": "Working at Meta & Industry",
    "Tier 8": "Computational Social Science",
    "Tier 9": "AI/ML for Behavioral Modeling",
    "Tier 10": "Research Methodology & Meta-Cognition",
    "Tier L1": "烹饪",
    "Tier L2": "地缘政治与世界",
    "Tier L3": "财富与个人财务",
    "Tier L4": "心理与关系",
    "Tier L5": "身体与健康",
    "Tier L6": "职场与软实力",
    "Tier L7": "科技前沿",
    "Tier L8": "历史与文明",
    "Tier L9": "思维与哲学",
    "Tier L10": "文化与审美",
    "Tier L11": "硬核好奇心",
    "Tier L12": "大问题",
  };

  const statusIcon = (s: string) => {
    if (s === "done") return "✅ Done";
    if (s === "skipped") return "❌ Skipped";
    return "⬜ Pending";
  };

  // Format title for skipped topics (wrap in ~~)
  const formatTitle = (t: QueueTopic) => {
    if (t.status === "skipped") return `~~${t.title}~~`;
    return t.title;
  };

  // Extract topic number from id (e.g. "L1_..." -> "L1", "5_..." -> "5")
  const getNum = (t: QueueTopic) => {
    const match = t.id.match(/^(L?\d+)_/);
    return match ? match[1] : "—";
  };

  let md = `# Topic Backlog — Book Generation Queue

> Auto-managed by Claude Code. Topics are picked in order.
> Mark as ✅ after generation. Add new topics at the bottom.
> User-specified topics for a given day override this queue.

## Priority Queue

`;

  // Academic tiers (1-10)
  for (const tierKey of tierOrder.filter((k) => !k.includes("L"))) {
    const items = grouped.get(tierKey);
    if (!items || items.length === 0) continue;

    const name = tierNames[tierKey] || tierKey;
    md += `### ${tierKey}: ${name}\n`;
    md += `| # | Topic | Status | Generated Date | Slot |\n`;
    md += `|---|-------|--------|---------------|------|\n`;

    for (const t of items) {
      const num = getNum(t);
      const title = formatTitle(t);
      const status = statusIcon(t.status);
      const date = t.generated_date || "";
      const slot = t.generated_slot || "";
      md += `| ${num} | ${title} | ${status} | ${date} | ${slot} |\n`;
    }
    md += "\n";
  }

  md += `---

## Life & Curiosity Topics

> 穿插在学术 topic 之间生成。大致节奏：每天3本中，2本学术 + 1本生活/好奇心，或根据当天心情调整。

`;

  // Life tiers (L1-L12)
  for (const tierKey of tierOrder.filter((k) => k.includes("L"))) {
    const items = grouped.get(tierKey);
    if (!items || items.length === 0) continue;

    const name = tierNames[tierKey] || tierKey;
    md += `### ${tierKey}: ${name}\n`;
    md += `| # | Topic | Status | Generated Date | Slot |\n`;
    md += `|---|-------|--------|---------------|------|\n`;

    for (const t of items) {
      const num = getNum(t);
      const title = formatTitle(t);
      const status = statusIcon(t.status);
      const date = t.generated_date || "";
      const slot = t.generated_slot || "";
      md += `| ${num} | ${title} | ${status} | ${date} | ${slot} |\n`;
    }
    md += "\n";
  }

  // Handle uncategorized topics
  const uncategorized = grouped.get("Uncategorized");
  if (uncategorized && uncategorized.length > 0) {
    md += `### Uncategorized\n`;
    md += `| # | Topic | Status | Generated Date | Slot |\n`;
    md += `|---|-------|--------|---------------|------|\n`;
    for (const t of uncategorized) {
      const title = formatTitle(t);
      const status = statusIcon(t.status);
      const date = t.generated_date || "";
      const slot = t.generated_slot || "";
      md += `| — | ${title} | ${status} | ${date} | ${slot} |\n`;
    }
    md += "\n";
  }

  // Completed Topics summary
  const done = topics.filter((t) => t.status === "done");
  if (done.length > 0) {
    md += `---

## Completed Topics
| # | Topic | Date | File |
|---|-------|------|------|
`;
    for (const t of done) {
      const num = getNum(t);
      // Extract short title (before any — or :)
      const shortTitle = t.title.split("—")[0].split(":")[0].trim();
      md += `| ${num} | ${shortTitle} | ${t.generated_date || ""} | ${t.generated_slot || ""} |\n`;
    }
  }

  md += `
---

## Auto-Topic Selection Rules
When the user hasn't specified topics for the day:
1. **RANDOM selection:** 从所有 ⬜ Pending 的 topic 中随机挑选，不按顺序，每次打乱
2. 学术和生活 topic 混在一起随机，不做固定比例
3. After generating, update status to ✅ and record date + file path
4. If a topic was partially covered in a previous book, go deeper rather than skip
5. Do NOT pick topics marked ❌ Skipped
`;

  fs.writeFileSync(BACKLOG_PATH, md, "utf-8");
}
