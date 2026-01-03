import CharacterDetailClient from "./CharacterDetailClient";

// Next 15: params/searchParams may be Promises in Server Components.
// Keep this page SSR-safe: no fetching here, only pass id to client.
export default async function CharacterDetailPage({ params }) {
  const p = await params;
  const characterId = p?.character_id;
  return <CharacterDetailClient characterId={characterId} />;
}
