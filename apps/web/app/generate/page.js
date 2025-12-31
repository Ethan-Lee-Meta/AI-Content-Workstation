import GenerateClient from "./GenerateClient";

export const dynamic = "force-dynamic";

export default async function Page({ searchParams }) {
  const sp = (searchParams && typeof searchParams.then === "function") ? await searchParams : (searchParams || {});
  const initialType = (sp && sp.type) ? String(sp.type) : "t2i";
  return <GenerateClient initialType={initialType} />;
}
