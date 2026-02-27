import { NextRequest, NextResponse } from "next/server";
import { getCurrentUser } from "@/lib/auth";
import {
  startGeneration,
  listJobs,
  getJobStatus,
  cancelGeneration,
} from "@/lib/book-generator";

/** POST: Start a new book generation */
export async function POST(req: NextRequest) {
  const user = await getCurrentUser();
  if (!user) {
    return NextResponse.json({ error: "Not authenticated" }, { status: 401 });
  }

  const { topic, queueTopicId } = await req.json();
  if (!topic) {
    return NextResponse.json({ error: "Topic required" }, { status: 400 });
  }

  const jobId = startGeneration(user.id, topic, queueTopicId || null);
  return NextResponse.json({ jobId, status: "running" }, { status: 202 });
}

/** GET: List active jobs or get specific job status */
export async function GET(req: NextRequest) {
  const user = await getCurrentUser();
  if (!user) {
    return NextResponse.json({ error: "Not authenticated" }, { status: 401 });
  }

  const jobId = req.nextUrl.searchParams.get("jobId");
  if (jobId) {
    const job = getJobStatus(jobId);
    if (!job) {
      return NextResponse.json({ error: "Job not found" }, { status: 404 });
    }
    return NextResponse.json(job);
  }

  return NextResponse.json({ jobs: listJobs() });
}

/** DELETE: Cancel a running generation */
export async function DELETE(req: NextRequest) {
  const user = await getCurrentUser();
  if (!user) {
    return NextResponse.json({ error: "Not authenticated" }, { status: 401 });
  }

  const jobId = req.nextUrl.searchParams.get("jobId");
  if (!jobId) {
    return NextResponse.json({ error: "jobId required" }, { status: 400 });
  }

  const cancelled = cancelGeneration(jobId);
  if (!cancelled) {
    return NextResponse.json(
      { error: "Job not found or not running" },
      { status: 404 }
    );
  }

  return NextResponse.json({ status: "cancelled" });
}
