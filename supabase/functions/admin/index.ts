import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("URL")!;
    const anonKey = Deno.env.get("ANON_KEY")!;
    const serviceRoleKey =
      Deno.env.get("SERVICE_ROLE_KEY") ??
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "Nao autenticado" }, 401);
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    const { data: userData, error: userError } =
      await userClient.auth.getUser();

    if (userError || !userData.user) {
      return json({ error: "Sessao invalida" }, 401);
    }

    const callerId = userData.user.id;
    const body = await req.json();
    const acao = body.acao;

    if (acao === "criar_empresa_com_admin") {
      await exigirAdminGlobal(adminClient, callerId);

      const nomeEmpresa = textoObrigatorio(body.nome_empresa);
      const nomeUsuario = textoObrigatorio(body.nome_usuario);
      const email = textoObrigatorio(body.email).toLowerCase();
      const senha = textoObrigatorio(body.senha);

      const { data: empresa, error: empresaError } = await adminClient
        .from("empresas")
        .insert({ nome: nomeEmpresa, ativo: true })
        .select("id")
        .single();

      if (empresaError) throw empresaError;

      const usuario = await criarOuBuscarUsuario(adminClient, {
        email,
        senha,
        nome: nomeUsuario,
      });

      const { error: vinculoError } = await adminClient
        .from("usuarios_empresas")
        .upsert(
          {
            user_id: usuario.id,
            empresa_id: empresa.id,
            nome: nomeUsuario,
            email,
            papel: "admin",
            ativo: true,
          },
          { onConflict: "user_id,empresa_id" },
        );

      if (vinculoError) throw vinculoError;

      return json({ ok: true, empresa_id: empresa.id, user_id: usuario.id });
    }

    if (acao === "criar_usuario_empresa") {
      const empresaId = textoObrigatorio(body.empresa_id);
      await exigirAdminEmpresa(adminClient, callerId, empresaId);

      const nome = textoObrigatorio(body.nome);
      const email = textoObrigatorio(body.email).toLowerCase();
      const senha = textoObrigatorio(body.senha);
      const papel = validarPapel(body.papel);

      const usuario = await criarOuBuscarUsuario(adminClient, {
        email,
        senha,
        nome,
      });

      const { error } = await adminClient.from("usuarios_empresas").upsert(
        {
          user_id: usuario.id,
          empresa_id: empresaId,
          nome,
          email,
          papel,
          ativo: true,
        },
        { onConflict: "user_id,empresa_id" },
      );

      if (error) throw error;

      return json({ ok: true, user_id: usuario.id });
    }

    if (acao === "atualizar_usuario_empresa") {
      const empresaId = textoObrigatorio(body.empresa_id);
      await exigirAdminEmpresa(adminClient, callerId, empresaId);

      const userId = textoObrigatorio(body.user_id);
      const papel = validarPapel(body.papel);
      const ativo = Boolean(body.ativo);

      const { error } = await adminClient
        .from("usuarios_empresas")
        .update({ papel, ativo })
        .eq("empresa_id", empresaId)
        .eq("user_id", userId);

      if (error) throw error;

      return json({ ok: true });
    }

    return json({ error: "Acao invalida" }, 400);
  } catch (error) {
    return json({ error: String(error?.message ?? error) }, 400);
  }
});

async function criarOuBuscarUsuario(
  adminClient: ReturnType<typeof createClient>,
  params: { email: string; senha: string; nome: string },
) {
  const { data, error } = await adminClient.auth.admin.createUser({
    email: params.email,
    password: params.senha,
    email_confirm: true,
    user_metadata: { nome: params.nome },
  });

  if (!error && data.user) return data.user;

  if (
    !String(error?.message ?? "")
      .toLowerCase()
      .includes("already")
  ) {
    throw error;
  }

  const { data: users, error: listError } =
    await adminClient.auth.admin.listUsers();

  if (listError) throw listError;

  const usuario = users.users.find((user) => user.email === params.email);
  if (!usuario) throw new Error("Usuario ja existe, mas nao foi localizado");

  return usuario;
}

async function exigirAdminGlobal(
  adminClient: ReturnType<typeof createClient>,
  userId: string,
) {
  const { data, error } = await adminClient
    .from("admins_globais")
    .select("user_id")
    .eq("user_id", userId)
    .maybeSingle();

  if (error) throw error;
  if (!data) throw new Error("Permissao de admin global necessaria");
}

async function exigirAdminEmpresa(
  adminClient: ReturnType<typeof createClient>,
  userId: string,
  empresaId: string,
) {
  const { data: global } = await adminClient
    .from("admins_globais")
    .select("user_id")
    .eq("user_id", userId)
    .maybeSingle();

  if (global) return;

  const { data, error } = await adminClient
    .from("usuarios_empresas")
    .select("papel, ativo")
    .eq("user_id", userId)
    .eq("empresa_id", empresaId)
    .maybeSingle();

  if (error) throw error;
  if (!data?.ativo || data.papel !== "admin") {
    throw new Error("Permissao de admin da empresa necessaria");
  }
}

function textoObrigatorio(value: unknown) {
  const texto = String(value ?? "").trim();
  if (!texto) throw new Error("Campo obrigatorio ausente");
  return texto;
}

function validarPapel(value: unknown) {
  const papel = String(value ?? "operador");
  if (["admin", "gerente", "operador", "consulta"].includes(papel)) {
    return papel;
  }
  throw new Error("Permissao invalida");
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
