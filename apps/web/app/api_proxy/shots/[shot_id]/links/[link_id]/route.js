import { forwardToApi } from "../../../../_lib";

export async function DELETE(req, ctx) {
  const { shot_id, link_id } = ctx.params;
  return forwardToApi(req, `/shots/${encodeURIComponent(shot_id)}/links/${encodeURIComponent(link_id)}`, {
    method: "DELETE",
  });
}
