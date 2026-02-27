import { readFileSync } from "fs";
import { resolve } from "path";
import { NextResponse } from "next/server";

export async function GET() {
  try {
    const certPath = resolve(process.cwd(), "certs/rootCA.pem");
    const cert = readFileSync(certPath);
    return new NextResponse(cert, {
      headers: {
        "Content-Type": "application/x-x509-ca-cert",
        "Content-Disposition": 'attachment; filename="BookFactory-CA.pem"',
      },
    });
  } catch {
    return NextResponse.json({ error: "Certificate not found" }, { status: 404 });
  }
}
