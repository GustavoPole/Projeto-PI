const express = require("express");
const cors = require("cors");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const db = require("./db");

const dbQuery = (sql, params) =>
  new Promise((resolve, reject) =>
    db.query(sql, params, (err, results) => (err ? reject(err) : resolve(results)))
  );
const { GoogleGenerativeAI } = require("@google/generative-ai");
require("dotenv").config();

const app = express();
app.use(cors());
app.use(express.json({ limit: '50mb' }));

const JWT_SECRET = process.env.JWT_SECRET;

const authenticateToken = (req, res, next) => {
  const authHeader = req.headers["authorization"];
  const token = authHeader && authHeader.split(" ")[1];
  if (!token) return res.status(401).json({ message: "Token não fornecido." });
  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) return res.status(403).json({ message: "Token inválido ou expirado." });
    req.user = user;
    next();
  });
};

app.post("/register", async (req, res) => {
  const { nome, cpf, email, password } = req.body;
  if (!nome || !cpf || !email || !password) {
    return res.status(400).json({ message: "Todos os campos são obrigatórios!" });
  }
  try {
    const hashedPassword = await bcrypt.hash(password, 10);
    const sql = "INSERT INTO user (nome, cpf, email, hash_password) VALUES (?, ?, ?, ?)";
    db.query(sql, [nome, cpf, email, hashedPassword], (err) => {
      if (err) {
        if (err.code === "ER_DUP_ENTRY") {
          return res.status(409).json({ message: "Este e-mail já está cadastrado." });
        }
        return res.status(500).json({ message: "Erro ao registrar usuário no banco." });
      }
      res.status(201).json({ message: "Usuário registrado com sucesso!" });
    });
  } catch (error) {
    res.status(500).json({ message: "Erro interno do servidor." });
  }
});

app.post("/login", (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) {
    return res.status(400).json({ message: "E-mail e senha são obrigatórios." });
  }
  const sql = "SELECT * FROM user WHERE email = ?";
  db.query(sql, [email], async (err, results) => {
    if (err) return res.status(500).json({ message: "Erro interno do servidor." });
    if (results.length === 0) {
      return res.status(401).json({ message: "E-mail ou senha inválidos." });
    }
    const user = results[0];
    const isMatch = await bcrypt.compare(password, user.hash_password);
    if (!isMatch) {
      return res.status(401).json({ message: "E-mail ou senha inválidos." });
    }
    const token = jwt.sign(
      { id: user.id, email: user.email, nome: user.nome },
      JWT_SECRET,
      { expiresIn: "8h" }
    );
    res.status(200).json({
      message: "Login bem-sucedido!",
      token,
      user: { id: user.id, nome: user.nome, email: user.email },
    });
  });
});

app.get("/profile", authenticateToken, (req, res) => {
  const sql = "SELECT id, nome, cpf, email FROM user WHERE id = ?";
  db.query(sql, [req.user.id], (err, results) => {
    if (err) return res.status(500).json({ message: "Erro ao buscar perfil." });
    if (results.length === 0) return res.status(404).json({ message: "Usuario nao encontrado." });
    res.status(200).json(results[0]);
  });
});

// PUT /profile -- atualiza nome e/ou email
app.put("/profile", authenticateToken, async (req, res) => {
  const { nome, email } = req.body;
  if (!nome && !email) {
    return res.status(400).json({ success: false, message: "Informe nome ou email." });
  }
  try {
    if (email) {
      const rows = await dbQuery("SELECT id FROM user WHERE email = ? AND id != ?", [email, req.user.id]);
      if (rows.length > 0) {
        return res.status(409).json({ success: false, message: "Este e-mail ja esta em uso." });
      }
    }
    const fields = [];
    const values = [];
    if (nome)  { fields.push("nome = ?");  values.push(nome.trim()); }
    if (email) { fields.push("email = ?"); values.push(email.trim()); }
    values.push(req.user.id);
    await dbQuery("UPDATE user SET " + fields.join(", ") + " WHERE id = ?", values);
    res.status(200).json({ success: true, message: "Perfil atualizado com sucesso." });
  } catch (err) {
    console.error("[PUT /profile]", err.message);
    res.status(500).json({ success: false, message: "Erro: " + err.message });
  }
});

// PUT /profile/password -- altera senha
app.put("/profile/password", authenticateToken, async (req, res) => {
  const { currentPassword, newPassword } = req.body;
  if (!currentPassword || !newPassword) {
    return res.status(400).json({ success: false, message: "Informe a senha atual e a nova senha." });
  }
  if (newPassword.length < 6) {
    return res.status(400).json({ success: false, message: "A nova senha deve ter pelo menos 6 caracteres." });
  }
  try {
    const rows = await dbQuery("SELECT hash_password FROM user WHERE id = ?", [req.user.id]);
    if (!rows.length) return res.status(404).json({ success: false, message: "Usuario nao encontrado." });
    const isMatch = await bcrypt.compare(currentPassword, rows[0].hash_password);
    if (!isMatch) return res.status(401).json({ success: false, message: "Senha atual incorreta." });
    const newHash = await bcrypt.hash(newPassword, 10);
    await dbQuery("UPDATE user SET hash_password = ? WHERE id = ?", [newHash, req.user.id]);
    res.status(200).json({ success: true, message: "Senha alterada com sucesso." });
  } catch (err) {
    console.error("[PUT /profile/password]", err.message);
    res.status(500).json({ success: false, message: "Erro: " + err.message });
  }
});

app.post("/api/generate-plan", authenticateToken, async (req, res) => {
  const { goal, weight, height, age, gender, activityLevel, waterGoal, allergies, preferences, pathologies } = req.body;

  console.log(" [IA] /api/generate-plan chamada — IA não implementada ainda.");
  res.status(200).json({
    success: true,
    message: "IA não implementada ainda. Usando dados simulados.",
    plan: {
      summary: `Plano personalizado para: ${goal}`,
      meals: [
        { name: "Café da manhã", time: "07:00", calories: 420 },
        { name: "Lanche da manhã", time: "10:00", calories: 230 },
        { name: "Almoço", time: "12:30", calories: 520 },
        { name: "Lanche da tarde", time: "15:30", calories: 180 },
        { name: "Jantar", time: "19:00", calories: 380 },
      ],
    },
  });
});

app.post("/api/diet-escape", authenticateToken, async (req, res) => {
  const { foodDescription, caloriesConsumed, caloriesGoal, proteinGoal, carbsGoal, fatGoal, planMeals } = req.body;
  if (!foodDescription) {
    return res.status(400).json({ success: false, message: "foodDescription e obrigatorio." });
  }

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    return res.status(200).json({
      success: true,
      analysis: {
        foodCalories: 250,
        foodPortion: "1 porcao tipica",
        message: "Fuga registrada! Vamos ajustar o restante do dia.",
        adjustments: [
          { meal: "Lanche da tarde", type: "reduce", food: "Porcao do lanche", amount: "-50%" },
          { meal: "Jantar", type: "reduce", food: "Carboidratos do jantar", amount: "-30g" },
        ],
        suggestion: "Frango grelhado com legumes no jantar",
        motivation: "Uma refeicao nao define sua jornada. Continue firme!",
      },
    });
  }

  try {
    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });

    const mealsContext = Array.isArray(planMeals) && planMeals.length > 0
      ? "Refeicoes restantes do plano hoje: " + planMeals.map(m => m.nome + (m.horario ? " (" + m.horario + ")" : "")).join(", ") + "."
      : "Sem informacoes das refeicoes do plano.";

    const lines = [
      "Voce e um nutricionista especialista. O usuario fugiu da dieta.",
      "",
      "Alimento consumido fora do plano: " + foodDescription,
      "Meta calorica diaria: " + (caloriesGoal || 0) + " kcal",
      "Ja consumiu hoje: " + (caloriesConsumed || 0) + " kcal",
      "Meta proteina: " + (proteinGoal || 0) + "g | Carboidratos: " + (carbsGoal || 0) + "g | Gordura: " + (fatGoal || 0) + "g",
      mealsContext,
      "",
      "TAREFA:",
      "1. Estime as calorias do alimento informado (porcao tipica).",
      "2. Calcule o impacto na meta diaria.",
      "3. Sugira compensacoes priorizando MICROREFEICOES (lanches) antes das refeicoes principais.",
      "4. Seja motivador e pratico.",
      "",
      "Retorne APENAS JSON valido sem markdown:",
      "{",
      '  "foodCalories": 0,',
      '  "foodPortion": "descricao da porcao tipica ex: 1 fatia 50g",',
      '  "message": "mensagem amigavel explicando o impacto",',
      '  "adjustments": [{"meal": "nome", "type": "reduce", "food": "alimento", "amount": "-50g"}],',
      '  "suggestion": "sugestao de refeicao saudavel",',
      '  "motivation": "frase motivacional curta"',
      "}",
    ];
    const prompt = lines.join("\n");
        const result = await model.generateContent(prompt);
    const text = result.response.text().trim();
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (!jsonMatch) throw new Error("Formato invalido");
    const parsed = JSON.parse(jsonMatch[0]);
    res.status(200).json({ success: true, analysis: parsed });
  } catch (error) {
    console.error("[diet-escape] Erro:", error.message);
    res.status(500).json({ success: false, message: "Erro ao consultar a IA: " + error.message });
  }
});

// POST /api/save-plan — salva plano criado manualmente com metas calculadas
app.post("/api/save-plan", authenticateToken, async (req, res) => {
  const userId = req.user.id;
  const { goal, weight, height, age, gender, activityLevel, waterGoal,
          caloriesGoal, proteinGoal, carbsGoal, fatGoal } = req.body;

  console.log(` [save-plan] userId=${userId} goal=${goal} cal=${caloriesGoal}`);

  try {
    // Desativa plano anterior
    await dbQuery(
      "UPDATE plano_alimentar SET ativo = 'Nao' WHERE usuario_id = ? AND ativo = 'Sim'",
      [userId]
    );

    const today = new Date().toISOString().split("T")[0];
    const nomePlano = `Plano ${goal || 'Personalizado'}`;

    const planResult = await dbQuery(
      "INSERT INTO plano_alimentar (usuario_id, nome, ativo, data_criacao) VALUES (?, ?, 'Sim', ?)",
      [userId, nomePlano, today]
    );
    const planId = planResult.insertId;
    console.log(` [save-plan] Plano #${planId} criado`);

    // Salva metas de macros
    await dbQuery("DELETE FROM max_micronutrientes WHERE id_user = ?", [userId]);
    await dbQuery(
      "INSERT INTO max_micronutrientes (calorias, proteinas, carbos, gordura, id_user) VALUES (?, ?, ?, ?, ?)",
      [caloriesGoal || 0, proteinGoal || 0, carbsGoal || 0, fatGoal || 0, userId]
    );
    console.log(` [save-plan] Macros salvos`);

    // Salva dados biométricos na tabela user_plan_meta (se existir)
    try {
      await dbQuery(
        `INSERT INTO user_plan_meta (user_id, goal, weight, height, age, gender, activity_level, water_goal)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE
           goal=VALUES(goal), weight=VALUES(weight), height=VALUES(height),
           age=VALUES(age), gender=VALUES(gender), activity_level=VALUES(activity_level),
           water_goal=VALUES(water_goal)`,
        [userId, goal, weight, height, age, gender, activityLevel, waterGoal]
      );
    } catch (_) {
      // Tabela pode não existir ainda — não bloqueia o fluxo
    }

    res.status(201).json({ success: true, planId });
  } catch (error) {
    console.error(" [save-plan] Erro:", error.message);
    res.status(500).json({ success: false, message: error.message });
  }
});

app.post("/api/food-swap", authenticateToken, async (req, res) => {
  const { foodName, goal, allergies, preferences } = req.body;

  if (!foodName) {
    return res.status(400).json({ success: false, message: "foodName é obrigatório." });
  }

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    console.warn("⚠️ GEMINI_API_KEY não configurada — retornando qualquer coisa para não quebrar o app.");
    return res.status(200).json({
      success: true,
      swaps: [
        { original: foodName, suggestion: "Batata doce", reason: "Menor índice glicêmico e mais fibras", ratio: "100g  120g", calories: 86 },
        { original: foodName, suggestion: "Quinoa", reason: "Proteína completa e sem glúten", ratio: "100g  80g", calories: 120 },
        { original: foodName, suggestion: "Mandioca cozida", reason: "Opção regional com bom valor nutricional", ratio: "100g  130g", calories: 125 },
      ],
    });
  }

  try {
    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });

    const allergyText = allergies?.length ? `Alergias do usuário: ${allergies.join(", ")}.` : "Sem alergias relatadas.";
    const prefText = preferences?.length ? `Preferências alimentares: ${preferences.join(", ")}.` : "";
    const goalText = goal ? `Objetivo nutricional: ${goal}.` : "";

    const prompt = `Você é um nutricionista especialista em alimentação saudável. Sugira exatamente 3 substitutos nutricionais para o alimento "${foodName}".
${goalText} ${allergyText} ${prefText}
Considere equivalência calórica e nutricional. Respeite as alergias.

Retorne APENAS um JSON válido, sem markdown, sem texto extra:
{
  "swaps": [
    {
      "suggestion": "Nome do alimento substituto",
      "reason": "Motivo nutricional objetivo em uma frase curta",
      "ratio": "100g  Xg",
      "calories": 0
    }
  ]
}`;

    const result = await model.generateContent(prompt);
    const text = result.response.text().trim();

    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (!jsonMatch) throw new Error("Resposta fora do formato esperado");

    const parsed = JSON.parse(jsonMatch[0]);
    const swaps = parsed.swaps.map((s) => ({ ...s, original: foodName }));

    console.log(` [Gemini] Trocas geradas para "${foodName}": ${swaps.map(s => s.suggestion).join(", ")}`);
    res.status(200).json({ success: true, swaps });
  } catch (error) {
    console.error(" [Gemini] Erro ao gerar trocas:", error.message);
    res.status(500).json({ success: false, message: "Erro ao consultar a IA: " + error.message });
  }
});


// GET /api/my-plan — retorna o plano ativo com refeições e alimentos (opcional ?date=YYYY-MM-DD aplica trocas do dia)
app.get("/api/my-plan", authenticateToken, async (req, res) => {
  const userId = req.user.id;
  const dateStr =
    typeof req.query.date === "string" && /^\d{4}-\d{2}-\d{2}$/.test(req.query.date)
      ? req.query.date
      : new Date().toISOString().split("T")[0];

  try {
    const plans = await dbQuery(
      "SELECT id, nome, data_criacao FROM plano_alimentar WHERE usuario_id = ? AND ativo = 'Sim' LIMIT 1",
      [userId]
    );
    if (plans.length === 0) {
      return res.status(200).json({ success: true, hasPlan: false, dataReferencia: dateStr });
    }
    const plan = plans[0];

    const rows = await dbQuery(
      `SELECT
        r.id        AS refeicao_id,
        r.nome      AS refeicao_nome,
        TIME_FORMAT(r.horario_previsto, '%H:%i') AS horario,
        i.id        AS item_refeicao_base_id,
        a.id        AS alimento_id,
        a.Nome      AS alimento_nome,
        a.porcao_g,
        a.calorias,
        a.proteinas,
        a.carbos,
        a.gorduras,
        i.quantidade_g
      FROM refeicoes_base r
      LEFT JOIN itens_refeicao_base i ON i.refeicao_id = r.id
      LEFT JOIN alimentos a ON a.id = i.alimento_id
      WHERE r.plano_id = ?
      ORDER BY r.horario_previsto, r.id, i.id`,
      [plan.id]
    );

    let swapByItem = {};
    try {
      const swapRows = await dbQuery(
        `SELECT item_refeicao_base_id, alimento_substituto_id
         FROM logs_diarios
         WHERE usuario_id = ? AND data = ? AND item_refeicao_base_id IS NOT NULL AND alimento_substituto_id IS NOT NULL
         ORDER BY id ASC`,
        [userId, dateStr]
      );
      for (const s of swapRows) {
        swapByItem[s.item_refeicao_base_id] = s.alimento_substituto_id;
      }
    } catch (e) {
      if (e.code === "ER_BAD_FIELD_ERROR") {
        swapByItem = {};
      } else throw e;
    }

    const subIds = [...new Set(Object.values(swapByItem))];
    let alimentoSubst = {};
    if (subIds.length > 0) {
      const ph = subIds.map(() => "?").join(",");
      const subs = await dbQuery(`SELECT id, Nome, porcao_g, calorias, proteinas, carbos, gorduras FROM alimentos WHERE id IN (${ph})`, subIds);
      for (const a of subs) alimentoSubst[a.id] = a;
    }

    // ── Busca alimentos adicionados manualmente no dia (itens_diario) ─────────
    // Estes NÃO estão em itens_refeicao_base — foram adicionados pelo usuário
    // via "Adicionar alimento". Precisam ser lidos e exibidos na mesma tela.
    let itensDiarioDeHoje = [];
    try {
      const diarioRows = await dbQuery(
        `SELECT
           id.id            AS item_id,
           id.quantidade_g  AS quantidade_g,
           id.tipo,
           id.refeicao_referencia,
           a.id             AS alimento_id,
           a.Nome           AS alimento_nome,
           a.porcao_g,
           a.calorias,
           a.proteinas,
           a.carbos,
           a.gorduras
         FROM itens_diario id
         JOIN logs_diarios  ld ON ld.id = id.diario_id
         JOIN alimentos      a  ON a.id  = id.alimento_id
         WHERE ld.usuario_id = ?
           AND ld.data       = ?
           AND ld.item_refeicao_base_id IS NULL
         ORDER BY id.id ASC`,
        [userId, dateStr]
      );
      itensDiarioDeHoje = diarioRows;
    } catch (e) {
      itensDiarioDeHoje = [];
    }

    const scaleMacro = (valueStr, factor) => (parseFloat(valueStr) || 0) * factor;

    const refeicaoMap = {};
    let sumCal = 0;
    let sumP = 0;
    let sumC = 0;
    let sumG = 0;

    for (const row of rows) {
      if (!refeicaoMap[row.refeicao_id]) {
        refeicaoMap[row.refeicao_id] = {
          id: row.refeicao_id,
          nome: row.refeicao_nome,
          horario: row.horario || "",
          alimentos: [],
        };
      }
      if (row.alimento_id && row.item_refeicao_base_id) {
        const subId = swapByItem[row.item_refeicao_base_id];
        const sub = subId ? alimentoSubst[subId] : null;
        const nomeOriginal = row.alimento_nome;
        const qtd = parseFloat(row.quantidade_g) || 0;
        const porcStr = sub ? sub.porcao_g : row.porcao_g;
        const porc = parseFloat(porcStr) || 100;
        const factor = porc > 0 ? qtd / porc : 1;

        const baseA = {
          id: row.alimento_id,
          item_refeicao_base_id: row.item_refeicao_base_id,
          nome: nomeOriginal,
          quantidade_g: qtd,
          porcao_g: String(porc),
          calorias: row.calorias || "0",
          proteinas: row.proteinas || "0",
          carbos: row.carbos || "0",
          gorduras: row.gorduras || "0",
          trocaDoDia: false,
        };
        if (sub) {
          baseA.trocaDoDia = true;
          baseA.alimento_original_id = row.alimento_id;
          baseA.alimento_original_nome = nomeOriginal;
          baseA.id = sub.id;
          baseA.nome = sub.Nome;
          baseA.calorias = sub.calorias || "0";
          baseA.proteinas = sub.proteinas || "0";
          baseA.carbos = sub.carbos || "0";
          baseA.gorduras = sub.gorduras || "0";
          baseA.porcao_g = String(parseFloat(sub.porcao_g) || 100);
        }

        const calStr = sub ? sub.calorias : row.calorias;
        const pStr = sub ? sub.proteinas : row.proteinas;
        const cStr = sub ? sub.carbos : row.carbos;
        const gStr = sub ? sub.gorduras : row.gorduras;
        sumCal += scaleMacro(calStr, factor);
        sumP += scaleMacro(pStr, factor);
        sumC += scaleMacro(cStr, factor);
        sumG += scaleMacro(gStr, factor);

        refeicaoMap[row.refeicao_id].alimentos.push(baseA);
      }
    }

    // ── Injeta alimentos manuais do dia nas refeições correspondentes ──────────
    // Agrupa por refeicao_referencia e cria uma refeição virtual se não existir
    for (const item of itensDiarioDeHoje) {
      const nomeRef = item.refeicao_referencia || "Outros";
      const qtd = parseFloat(item.quantidade_g) || 100;
      const porc = parseFloat(item.porcao_g) || 100;
      const factor = porc > 0 ? qtd / porc : 1;

      sumCal += scaleMacro(item.calorias, factor);
      sumP   += scaleMacro(item.proteinas, factor);
      sumC   += scaleMacro(item.carbos, factor);
      sumG   += scaleMacro(item.gorduras, factor);

      // Tenta encontrar a refeição base pelo nome (case-insensitive)
      const refEntry = Object.values(refeicaoMap).find(
        r => r.nome && r.nome.toLowerCase() === nomeRef.toLowerCase()
      );

      const alimentoItem = {
        id: item.alimento_id,
        item_refeicao_base_id: null,   // não é do plano base
        adicionadoManualmente: true,
        nome: item.alimento_nome,
        quantidade_g: qtd,
        porcao_g: String(porc),
        calorias: item.calorias || "0",
        proteinas: item.proteinas || "0",
        carbos: item.carbos || "0",
        gorduras: item.gorduras || "0",
        trocaDoDia: false,
      };

      if (refEntry) {
        refEntry.alimentos.push(alimentoItem);
      } else {
        // Cria entrada virtual para refeições sem scan (categorias padrão)
        const virtId = `manual_${nomeRef}`;
        if (!refeicaoMap[virtId]) {
          refeicaoMap[virtId] = {
            id: virtId,
            nome: nomeRef,
            horario: "",
            alimentos: [],
          };
        }
        refeicaoMap[virtId].alimentos.push(alimentoItem);
      }
    }

    const kcalP = sumP * 4;
    const kcalC = sumC * 4;
    const kcalG = sumG * 9;
    const kcalMacros = kcalP + kcalC + kcalG;
    let pctProteina = 0;
    let pctCarboidrato = 0;
    let pctGordura = 0;
    if (kcalMacros > 0) {
      pctProteina = Math.round((100 * kcalP) / kcalMacros);
      pctCarboidrato = Math.round((100 * kcalC) / kcalMacros);
      pctGordura = Math.max(0, 100 - pctProteina - pctCarboidrato);
    }

    let metas = null;
    try {
      const mmRows = await dbQuery(
        "SELECT calorias, proteinas, carbos, gordura FROM max_micronutrientes WHERE id_user = ? LIMIT 1",
        [userId]
      );
      if (mmRows.length > 0) {
        const m = mmRows[0];
        metas = {
          calorias: Number(m.calorias) || 0,
          proteinas: Number(m.proteinas) || 0,
          carbos: Number(m.carbos) || 0,
          gordura: Number(m.gordura) || 0,
        };
      }
    } catch (e) {
      metas = null;
    }

    const resumo_nutricional = {
      calorias_total: Math.round(sumCal),
      proteinas_g: Math.round(sumP * 10) / 10,
      carbos_g: Math.round(sumC * 10) / 10,
      gorduras_g: Math.round(sumG * 10) / 10,
      distribuicao_pct: {
        proteina: pctProteina,
        carboidrato: pctCarboidrato,
        gordura: pctGordura,
      },
      metas,
    };

    // Busca dados biométricos salvos na user_plan_meta
    let planMeta = null;
    try {
      const metaRows = await dbQuery(
        "SELECT goal, weight, height, age, gender, activity_level AS activityLevel, water_goal AS waterGoal FROM user_plan_meta WHERE user_id = ? LIMIT 1",
        [userId]
      );
      if (metaRows.length > 0) {
        planMeta = metaRows[0];
      }
    } catch (_) {}

    res.status(200).json({
      success: true,
      hasPlan: true,
      dataReferencia: dateStr,
      plan: {
        id: plan.id,
        nome: plan.nome,
        data_criacao: plan.data_criacao,
        refeicoes: Object.values(refeicaoMap),
        resumo_nutricional,
      },
      plan_meta: planMeta,
    });
  } catch (error) {
    console.error(" [DB] Erro ao buscar plano:", error.message);
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/accept-food-swap — cadastra substituto em alimentos e registra em logs_diarios para o dia
app.post("/api/accept-food-swap", authenticateToken, async (req, res) => {
  const userId = req.user.id;
  const { data, item_refeicao_base_id, novoAlimento } = req.body;

  if (!data || !/^\d{4}-\d{2}-\d{2}$/.test(String(data))) {
    return res.status(400).json({ success: false, message: "Campo data é obrigatório (YYYY-MM-DD)." });
  }
  const itemId = parseInt(item_refeicao_base_id, 10) || 0;
  if (!novoAlimento || typeof novoAlimento.Nome !== "string" || !novoAlimento.Nome.trim()) {
    return res.status(400).json({ success: false, message: "novoAlimento.Nome é obrigatório." });
  }

  try {
    // itemId=0 = item adicionado manualmente (não veio do scan/plano base)
    // itemId>0 = item do plano base — valida pertencimento ao plano do usuário
    let planId = null;
    if (itemId > 0) {
      const itemRows = await dbQuery(
        `SELECT i.id, i.quantidade_g, i.alimento_id, r.plano_id
         FROM itens_refeicao_base i
         INNER JOIN refeicoes_base r ON r.id = i.refeicao_id
         INNER JOIN plano_alimentar p ON p.id = r.plano_id
         WHERE i.id = ? AND p.usuario_id = ? AND p.ativo = 'Sim'`,
        [itemId, userId]
      );
      if (itemRows.length === 0) {
        return res.status(403).json({ success: false, message: "Item não pertence ao seu plano ativo." });
      }
      planId = itemRows[0].plano_id;
    } else {
      // Para itens manuais, pega o plano ativo do usuário
      const planRows = await dbQuery(
        "SELECT id FROM plano_alimentar WHERE usuario_id = ? AND ativo = 'Sim' LIMIT 1",
        [userId]
      );
      if (planRows.length > 0) planId = planRows[0].id;
    }

    const nome = novoAlimento.Nome.trim();
    const porcao = String(novoAlimento.porcao_g ?? "100");
    const cal = String(novoAlimento.calorias ?? "0");
    const prot = String(novoAlimento.proteinas ?? "0");
    const carb = String(novoAlimento.carbos ?? "0");
    const gord = String(novoAlimento.gorduras ?? "0");

    const existing = await dbQuery("SELECT id FROM alimentos WHERE Nome = ?", [nome]);
    let alimentoSubstitutoId;
    if (existing.length > 0) {
      alimentoSubstitutoId = existing[0].id;
    } else {
      const ins = await dbQuery(
        "INSERT INTO alimentos (Nome, porcao_g, calorias, proteinas, carbos, gorduras) VALUES (?, ?, ?, ?, ?, ?)",
        [nome, porcao, cal, prot, carb, gord]
      );
      alimentoSubstitutoId = ins.insertId;
    }

    if (itemId > 0) {
      // ── Item do plano base (scan): deleta troca anterior e grava nova em logs_diarios
      await dbQuery(
        "DELETE FROM logs_diarios WHERE usuario_id = ? AND data = ? AND item_refeicao_base_id = ?",
        [userId, data, itemId]
      );
      await dbQuery(
        `INSERT INTO logs_diarios (usuario_id, data, calorias_consumidas, status, plano_id, item_refeicao_base_id, alimento_substituto_id)
         VALUES (?, ?, ?, 'no_plano', ?, ?, ?)`,
        [userId, data, cal, planId, itemId, alimentoSubstitutoId]
      );
    } else {
      // ── Item manual: atualiza o alimento_id diretamente em itens_diario
      // para o substituto escolhido, mantendo a data e refeição.
      // Identifica o item pelo alimento_id original enviado pelo Flutter.
      const alimentoOriginalId = parseInt(req.body.alimento_original_id, 10) || null;

      if (alimentoOriginalId) {
        // Acha o diário do dia
        const [diario] = await dbQuery(
          "SELECT id FROM logs_diarios WHERE usuario_id = ? AND data = ? AND item_refeicao_base_id IS NULL LIMIT 1",
          [userId, data]
        );
        if (diario) {
          // Atualiza o item manual para apontar para o novo alimento
          await dbQuery(
            `UPDATE itens_diario
             SET alimento_id = ?
             WHERE diario_id = ? AND alimento_id = ?
             LIMIT 1`,
            [alimentoSubstitutoId, diario.id, alimentoOriginalId]
          );
        }
      }

      // Registra também em logs_diarios para histórico e para o "voltar no dia seguinte"
      await dbQuery(
        `INSERT INTO logs_diarios (usuario_id, data, calorias_consumidas, status, plano_id, item_refeicao_base_id, alimento_substituto_id)
         VALUES (?, ?, ?, 'no_plano', ?, NULL, ?)`,
        [userId, data, cal, planId, alimentoSubstitutoId]
      );
    }

    console.log("[DB] Troca registrada: usuario " + userId + ", item " + itemId + " -> alimento " + alimentoSubstitutoId + " em " + data);
    res.status(200).json({ success: true, alimento_substituto_id: alimentoSubstitutoId });
  } catch (error) {
    console.error("[DB] Erro ao registrar troca:", error.message);
    if (error.code === "ER_BAD_FIELD_ERROR") {
      return res.status(500).json({
        success: false,
        message:
          "Banco sem colunas de troca em logs_diarios. Execute o script diethub_api/sql/alter_logs_diarios_trocas.sql",
      });
    }
    res.status(500).json({ success: false, message: error.message });
  }
});



// POST /api/scan-plan — envia imagem/PDF para o Gemini e retorna JSON
app.post("/api/scan-plan", authenticateToken, async (req, res) => {
  const { fileBase64, mimeType } = req.body;

  if (!fileBase64 || !mimeType) {
    return res.status(400).json({ success: false, message: "fileBase64 e mimeType são obrigatórios." });
  }

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    return res.status(400).json({ success: false, message: "GEMINI_API_KEY não configurada no servidor. Adicione a chave no arquivo .env." });
  }

  try {
    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });

    const prompt = `Você é um nutricionista especialista. Analise este documento de plano alimentar e extraia TODAS as informações nutricionais presentes.

Retorne APENAS um JSON válido, sem markdown, sem blocos de código, sem texto extra. Use exatamente este formato:
{
  "plano": {
    "nome": "Nome do plano ou 'Plano Alimentar Digitalizado' se não houver nome"
  },
  "max_micronutrientes": {
    "calorias": 0,
    "proteinas": 0,
    "carbos": 0,
    "gordura": 0
  },
  "refeicoes": [
    {
      "nome": "Nome da refeição (ex: Café da manhã, Almoço)",
      "horario_previsto": "HH:MM:SS",
      "alimentos": [
        {
          "Nome": "Nome exato do alimento",
          "porcao_g": "100",
          "calorias": "0",
          "proteinas": "0",
          "carbos": "0",
          "gorduras": "0",
          "quantidade_g": 100
        }
      ]
    }
  ]
}

Regras:
- porcao_g, calorias, proteinas, carbos, gorduras devem ser strings numéricas
- quantidade_g deve ser number
- horario_previsto no formato HH:MM:SS (ex: "07:00:00")
- Se um valor não estiver no documento, estime com base em valores nutricionais típicos do alimento
- Extraia TODAS as refeições e TODOS os alimentos visíveis no documento`;

    const result = await model.generateContent([
      { inlineData: { data: fileBase64, mimeType } },
      prompt,
    ]);

    const text = result.response.text().trim();
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (!jsonMatch) throw new Error("A IA retornou uma resposta fora do formato esperado.");

    const data = JSON.parse(jsonMatch[0]);
    console.log(` [Gemini Scan] Plano extraído: ${data.refeicoes?.length ?? 0} refeições.`);
    res.status(200).json({ success: true, data });
  } catch (error) {
    console.error(" [Gemini Scan] Erro:", error.message);
    res.status(500).json({ success: false, message: "Erro ao analisar o arquivo: " + error.message });
  }
});


// POST /api/save-scanned-plan — salva o plano da ia no banco
//ordem: plano_alimentar  refeicoes_base  alimentos  itens_refeicao_base  max_micronutrientes (revisar depois a estrutura do banco itens_diarios) 
app.post("/api/save-scanned-plan", authenticateToken, async (req, res) => {
  const { data } = req.body;
  const userId = req.user.id;

  if (!data || !data.plano || !Array.isArray(data.refeicoes)) {
    return res.status(400).json({ success: false, message: "Dados do plano inválidos ou incompletos." });
  }

  try {
    //desativa planos anteriores
    await dbQuery("UPDATE plano_alimentar SET ativo = 'Nao' WHERE usuario_id = ? AND ativo = 'Sim'", [userId]);

    // cria a dieta nova
    const today = new Date().toISOString().split("T")[0];
    const planResult = await dbQuery(
      "INSERT INTO plano_alimentar (usuario_id, nome, ativo, data_criacao) VALUES (?, ?, 'Sim', ?)",
      [userId, data.plano.nome || "Plano Alimentar Digitalizado", today]
    );
    const planId = planResult.insertId;

    // salva max_micronutrientes
    if (data.max_micronutrientes) {
      const mm = data.max_micronutrientes;
      await dbQuery("DELETE FROM max_micronutrientes WHERE id_user = ?", [userId]);
      await dbQuery(
        "INSERT INTO max_micronutrientes (calorias, proteinas, carbos, gordura, id_user) VALUES (?, ?, ?, ?, ?)",
        [mm.calorias || 0, mm.proteinas || 0, mm.carbos || 0, mm.gordura || 0, userId]
      );
    }

    // cria cada refeição e seus alimentos
    for (const refeicao of data.refeicoes) {
      const refResult = await dbQuery(
        "INSERT INTO refeicoes_base (plano_id, nome, horario_previsto) VALUES (?, ?, ?)",
        [planId, refeicao.nome || "Refeição", refeicao.horario_previsto || "00:00:00"]
      );
      const refeicaoId = refResult.insertId;

      for (const alimento of (refeicao.alimentos || [])) {
        // reutiliza alimento existente (noem igual) ou cria novo
        const existing = await dbQuery("SELECT id FROM alimentos WHERE Nome = ?", [alimento.Nome]);
        let alimentoId;

        if (existing.length > 0) {
          alimentoId = existing[0].id;
        } else {
          const aResult = await dbQuery(
            "INSERT INTO alimentos (Nome, porcao_g, calorias, proteinas, carbos, gorduras) VALUES (?, ?, ?, ?, ?, ?)",
            [
              alimento.Nome,
              String(alimento.porcao_g || "100"),
              String(alimento.calorias || "0"),
              String(alimento.proteinas || "0"),
              String(alimento.carbos || "0"),
              String(alimento.gorduras || "0"),
            ]
          );
          alimentoId = aResult.insertId;
        }

        await dbQuery(
          "INSERT INTO itens_refeicao_base (refeicao_id, alimento_id, quantidade_g) VALUES (?, ?, ?)",
          [refeicaoId, alimentoId, parseFloat(alimento.quantidade_g) || 100]
        );
      }
    }

    console.log(` [DB] Plano #${planId} salvo para usuário ${userId}.`);
    res.status(200).json({ success: true, planId });
  } catch (error) {
    console.error(" [DB] Erro ao salvar plano:", error.message);
    res.status(500).json({ success: false, message: "Erro ao salvar no banco: " + error.message });
  }
});

// POST /api/log-refeicao — registra um alimento consumido no dia
// Campos obrigatórios: quantidade_g, tipo, refeicao_referencia
// Campos opcionais:   alimento_id (0 ou ausente = cria pelo nome),
//                     item_refeicao_base_id, alimento_novo_id
// Nota: item_refeicao_base_id e plano_id em logs_diarios aceitam NULL —
//       o registro comum de alimentos não preenche esses campos,
//       somente as trocas com IA (accept-food-swap) os preenchem.
app.post("/api/log-refeicao", authenticateToken, async (req, res) => {
  const userId = req.user.id;
  const { alimento_id, quantidade_g, tipo, refeicao_referencia, nome, alimento_novo_id } = req.body;

  if (!quantidade_g || !tipo) {
    return res.status(400).json({ success: false, message: "quantidade_g e tipo sao obrigatorios." });
  }

  try {
    const today = new Date().toISOString().slice(0, 10);

    // Resolve alimento_id
    let resolvedAlimentoId = alimento_novo_id || alimento_id || null;
    if (!resolvedAlimentoId || resolvedAlimentoId === 0) {
      const nomeAlimento = (nome && nome.toString().trim()) || refeicao_referencia || "Alimento";
      const existingAl = await dbQuery("SELECT id FROM alimentos WHERE Nome = ? LIMIT 1", [nomeAlimento]);
      if (existingAl.length > 0) {
        resolvedAlimentoId = existingAl[0].id;
      } else {
        const insertAl = await dbQuery(
          "INSERT INTO alimentos (Nome, porcao_g, calorias, proteinas, carbos, gorduras) VALUES (?, ?, ?, ?, ?, ?)",
          [nomeAlimento, String(parseFloat(quantidade_g) || 100), "0", "0", "0", "0"]
        );
        resolvedAlimentoId = insertAl.insertId;
      }
    }

    // Garante log do dia
    const existingLog = await dbQuery(
      "SELECT id FROM logs_diarios WHERE usuario_id = ? AND data = ? AND item_refeicao_base_id IS NULL LIMIT 1",
      [userId, today]
    );
    let diarioId;
    if (existingLog.length > 0) {
      diarioId = existingLog[0].id;
    } else {
      const ins = await dbQuery(
        "INSERT INTO logs_diarios (usuario_id, data, calorias_consumidas, item_refeicao_base_id, alimento_substituto_id, plano_id, status) VALUES (?, ?, ?, NULL, NULL, NULL, NULL)",
        [userId, today, "0"]
      );
      diarioId = ins.insertId;
    }

    // tipo ENUM: 'planejado' | 'consumido' | 'fuga'
    const tipoValido = ["planejado", "consumido", "fuga"].includes(tipo) ? tipo : "consumido";

    await dbQuery(
      "INSERT INTO itens_diario (diario_id, alimento_id, quantidade_g, tipo, refeicao_referencia) VALUES (?, ?, ?, ?, ?)",
      [diarioId, resolvedAlimentoId, parseFloat(quantidade_g) || 100, tipoValido, refeicao_referencia || null]
    );

    res.status(201).json({ success: true, message: "Refeicao registrada com sucesso." });
  } catch (error) {
    console.error("[log-refeicao] Erro:", error.message, "| code:", error.code);
    res.status(500).json({ success: false, message: "Erro ao salvar refeicao: " + error.message });
  }
});
app.listen(3000, () => {
    console.log("Servidor DietHub rodando em http://localhost:3000");
});