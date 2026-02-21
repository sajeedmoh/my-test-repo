'use strict';

require('dotenv').config();

const express = require('express');
const cors    = require('cors');
const bcrypt  = require('bcryptjs');
const jwt     = require('jsonwebtoken');
const path    = require('path');

const {
  DynamoDBClient,
  CreateTableCommand,
  DescribeTableCommand,
} = require('@aws-sdk/client-dynamodb');

const {
  DynamoDBDocumentClient,
  GetCommand,
  PutCommand,
} = require('@aws-sdk/lib-dynamodb');

// ── Config ────────────────────────────────────────────────────────────────────
const PORT       = process.env.PORT        || 3000;
const JWT_SECRET = process.env.JWT_SECRET;
const TABLE_NAME = process.env.DYNAMODB_TABLE || 'auth_users';
const AWS_REGION = process.env.AWS_REGION    || 'us-east-1';

if (!JWT_SECRET) {
  console.error('ERROR: JWT_SECRET is not set — please add it and restart.');
  process.exit(1);
}

// ── DynamoDB ──────────────────────────────────────────────────────────────────
// In Lambda: SDK auto-detects credentials from the execution role (no explicit creds needed)
// Locally:   SDK picks up AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY from .env via dotenv
const dynamo = new DynamoDBClient({ region: AWS_REGION });

const db = DynamoDBDocumentClient.from(dynamo);

async function ensureTable() {
  try {
    await dynamo.send(new DescribeTableCommand({ TableName: TABLE_NAME }));
    console.log(`✓ DynamoDB table "${TABLE_NAME}" is ready.`);
  } catch (err) {
    if (err.name !== 'ResourceNotFoundException') throw err;

    console.log(`  Creating DynamoDB table "${TABLE_NAME}"…`);
    await dynamo.send(new CreateTableCommand({
      TableName: TABLE_NAME,
      AttributeDefinitions: [{ AttributeName: 'email', AttributeType: 'S' }],
      KeySchema:            [{ AttributeName: 'email', KeyType: 'HASH'   }],
      BillingMode: 'PAY_PER_REQUEST',
    }));

    // Poll until ACTIVE
    let active = false;
    while (!active) {
      await new Promise(r => setTimeout(r, 1500));
      const { Table } = await dynamo.send(new DescribeTableCommand({ TableName: TABLE_NAME }));
      active = Table.TableStatus === 'ACTIVE';
    }
    console.log(`✓ Table "${TABLE_NAME}" created and active.`);
  }
}

// ── Express ───────────────────────────────────────────────────────────────────
const app = express();
app.use(cors());
app.use(express.json());

// Serve the HTML files at the root (e.g. http://localhost:3000/login.html)
app.use(express.static(path.join(__dirname, '..')));

// ── POST /api/auth/register ───────────────────────────────────────────────────
app.post('/api/auth/register', async (req, res) => {
  try {
    const { firstName, lastName, email, password } = req.body || {};

    if (!firstName || !lastName || !email || !password) {
      return res.status(400).json({ error: 'All fields are required.' });
    }

    const normalEmail = email.trim().toLowerCase();

    // Duplicate check
    const existing = await db.send(new GetCommand({
      TableName: TABLE_NAME,
      Key: { email: normalEmail },
    }));

    if (existing.Item) {
      return res.status(409).json({ error: 'An account with this email already exists.' });
    }

    const passwordHash = await bcrypt.hash(password, 12);

    await db.send(new PutCommand({
      TableName: TABLE_NAME,
      Item: {
        email:        normalEmail,
        firstName:    firstName.trim(),
        lastName:     lastName.trim(),
        passwordHash,
        createdAt:    new Date().toISOString(),
      },
    }));

    return res.json({ success: true });

  } catch (err) {
    console.error('Register error:', err);
    return res.status(500).json({ error: 'Server error. Please try again.' });
  }
});

// ── POST /api/auth/login ──────────────────────────────────────────────────────
app.post('/api/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body || {};

    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required.' });
    }

    const normalEmail = email.trim().toLowerCase();

    const result = await db.send(new GetCommand({
      TableName: TABLE_NAME,
      Key: { email: normalEmail },
    }));

    if (!result.Item) {
      return res.status(401).json({ error: 'Invalid email or password.' });
    }

    const match = await bcrypt.compare(password, result.Item.passwordHash);
    if (!match) {
      return res.status(401).json({ error: 'Invalid email or password.' });
    }

    const user = {
      email:     result.Item.email,
      firstName: result.Item.firstName,
      lastName:  result.Item.lastName,
    };

    const token = jwt.sign(user, JWT_SECRET, { expiresIn: '7d' });
    return res.json({ token, user });

  } catch (err) {
    console.error('Login error:', err);
    return res.status(500).json({ error: 'Server error. Please try again.' });
  }
});

// ── Lambda handler ────────────────────────────────────────────────────────────
let _serverlessHandler;
let _tableReady = false;

async function getLambdaHandler() {
  if (!_tableReady) {
    await ensureTable();
    _tableReady = true;
  }
  if (!_serverlessHandler) {
    const serverless = require('serverless-http');
    _serverlessHandler = serverless(app);
  }
  return _serverlessHandler;
}

exports.handler = async (event, context) => {
  const h = await getLambdaHandler();
  return h(event, context);
};

// ── Local dev server ──────────────────────────────────────────────────────────
if (require.main === module) {
  ensureTable()
    .then(() => {
      app.listen(PORT, () => {
        console.log(`\n✓ Server running → http://localhost:${PORT}`);
        console.log(`  Open http://localhost:${PORT}/login.html\n`);
      });
    })
    .catch(err => {
      console.error('Failed to connect to DynamoDB:', err.message);
      process.exit(1);
    });
}
