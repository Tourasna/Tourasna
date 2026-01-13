import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js";

serve(async (req) => {
  try {
    console.log("CHATBOT HIT");

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    let body;
    try {
      body = await req.json();
    } catch {
      throw new Error("Invalid JSON body");
    }

    const message = body.message;
    const session_id = body.session_id ?? null;

    if (!message) {
      throw new Error("Missing message");
    }

    // ---- USER / ANON ID ----
    const userRes = await supabase.auth.getUser(req);
    const userId = userRes.data.user?.id ?? null;


    // ---- SESSION ----
    let sessionId = session_id;

    if (!sessionId) {
      const { data, error } = await supabase
        .from("chat_sessions")
        .insert({ user_id: userId })
        .select()
        .single();

      if (error) throw error;
      sessionId = data.id;
    }

    // ---- HISTORY ----
    const { data: historyData } = await supabase
      .from("chat_messages")
      .select("role, content")
      .eq("session_id", sessionId)
      .order("created_at", { ascending: true })
      .limit(10);

    const history = historyData ?? [];

    // ---- AI CALL ----
    const aiRes = await fetch("https://fahmy-chatbot.fly.dev/chat", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ message, history }),
    });

    if (!aiRes.ok) {
      const text = await aiRes.text();
      throw new Error(`AI error ${aiRes.status}: ${text}`);
    }

    const aiJson = await aiRes.json();

    if (!aiJson.message) {
      throw new Error("AI response missing message");
    }

    // ---- SAVE ----
    await supabase.from("chat_messages").insert([
      { session_id: sessionId, role: "user", content: message },
      { session_id: sessionId, role: "assistant", content: aiJson.message },
    ]);

    return new Response(
      JSON.stringify({
        session_id: sessionId,
        message: aiJson.message,
      }),
      {
        headers: {
          "Content-Type": "application/json",
          "Set-Cookie": `anon_id=${userId}; Path=/; HttpOnly`,
        },
      }
    );
  } catch (err) {
    console.error("CHATBOT EDGE ERROR:", err);

    return new Response(
      JSON.stringify({
        message: "Chatbot internal error",
      }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
