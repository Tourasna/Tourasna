import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  // 1️⃣ Auth check
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response("Unauthorized", { status: 401 });
  }

  const token = authHeader.replace("Bearer ", "");
  const { data: userData, error: authError } =
    await supabase.auth.getUser(token);

  if (authError || !userData.user) {
    return new Response("Invalid user", { status: 401 });
  }

  const userId = userData.user.id;

  // 2️⃣ Fetch user profile
  const { data: profile } = await supabase
    .from("profiles")
    .select("*")
    .eq("id", userId)
    .single();

  // 3️⃣ Fetch favorites
  const { data: favorites } = await supabase
    .from("favorites")
    .select("place_id")
    .eq("user_id", userId);

  // 4️⃣ Build payload
  const payload = {
    user_id: userId,
    profile,
    favorites: favorites?.map((f) => f.place_id) ?? [],
  };

  // 5️⃣ Call AI backend
  const aiResponse = await fetch(
    `${Deno.env.get("AI_BACKEND_URL")}/recommend`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    }
  );

  if (!aiResponse.ok) {
    return new Response("AI backend error", { status: 500 });
  }

  const result = await aiResponse.json();

  // 6️⃣ Return result
  return new Response(JSON.stringify(result), {
    headers: { "Content-Type": "application/json" },
  });
});
