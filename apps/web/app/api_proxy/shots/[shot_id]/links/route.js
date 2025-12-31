import { forwardToApi } from "../../../_lib";

export async function POST(req, ctx) {
  const shotId = ctx.params.shot_id;
  const body = await req.text();
  return forwardToApi(req, `/shots/${encodeURIComponent(shotId)}/links`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body,
  });
}
