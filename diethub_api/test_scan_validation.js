/**
 * SCRIPT DE TESTE: Validação de Plano Alimentar com IA
 * 
 * Este script demonstra a capacidade do sistema de identificar se um arquivo
 * enviado é realmente um plano alimentar ou não, utilizando a API do Gemini.
 * 
 * Uso: node test_scan_validation.js
 */

const fs = require('fs');
const path = require('path');
const { GoogleGenerativeAI } = require("@google/generative-ai");
require("dotenv").config();

async function runTest(testName, imagePath) {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    console.error("❌ Erro: GEMINI_API_KEY não encontrada no arquivo .env");
    return;
  }

  console.log(`\n--- Testando: ${testName} ---`);
  
  if (!fs.existsSync(imagePath)) {
    console.error(`❌ Erro: Arquivo não encontrado em ${imagePath}`);
    return;
  }

  const genAI = new GoogleGenerativeAI(apiKey);
  const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });

  const fileBase64 = fs.readFileSync(imagePath).toString('base64');
  const mimeType = 'image/png';

  // Mesmo prompt utilizado no servidor para garantir consistência
  const prompt = `Você é um nutricionista especialista. Analise o arquivo enviado.

IMPORTANTE: Se o arquivo NÃO for um plano alimentar (por exemplo: foto de pessoa, animal, objeto, paisagem, ou documento sem relação com dieta), retorne EXATAMENTE este JSON:
{
  "is_plano_alimentar": false,
  "mensagem": "O arquivo enviado não foi identificado como um plano alimentar. Por favor, envie uma imagem ou PDF da sua dieta."
}

Se o arquivo FOR um plano alimentar, extraia as informações e retorne EXATAMENTE este formato JSON:
{
  "is_plano_alimentar": true,
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

Regras: APENAS JSON, sem markdown.`;

  console.log(`📤 Enviando ${path.basename(imagePath)} para análise...`);

  try {
    const result = await model.generateContent([
      { inlineData: { data: fileBase64, mimeType } },
      prompt,
    ]);

    const text = result.response.text().trim();
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    
    if (!jsonMatch) {
      console.log("📥 Resposta bruta (não JSON):", text);
      return;
    }

    const data = JSON.parse(jsonMatch[0]);
    console.log("📥 Resposta Estruturada da IA:");
    console.log(JSON.stringify(data, null, 2));

    if (data.is_plano_alimentar === false) {
      console.log("\n✅ VALIDAÇÃO: A IA bloqueou o arquivo corretamente (Não é um plano).");
    } else {
      console.log("\n✅ IDENTIFICAÇÃO: A IA reconheceu como um plano alimentar e extraiu os dados.");
    }
  } catch (error) {
    console.error("❌ Erro durante a análise:", error.message);
  }
}

async function start() {
  console.log("🚀 Iniciando Teste de Validação de IA - DietHub");
  
  // Teste 1: Um arquivo que NÃO é plano alimentar (Favicon)
  await runTest(
    "Arquivo Inválido (Ícone do Sistema)", 
    path.join(__dirname, '..', 'web', 'favicon.png')
  );

  // Teste 2: Um arquivo que pode ser interpretado como plano (Placeholder)
  await runTest(
    "Arquivo de Placeholder (Ilustrativo)", 
    path.join(__dirname, '..', 'assets', 'images', 'food_scan_placeholder.png')
  );

  console.log("\n--- Fim dos Testes ---");
}

start();
