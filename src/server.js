
const express = require('express');
const fs = require('fs');
const path = require('path');
const { hashPassword, generateToken } = require('./utils');

const app = express();
const port = 3000;

app.use(express.json());

const API_KEY = 'supersecretapikey123'; 

app.get('/file', (req, res) => {
  const filePath = req.query.path; 
  fs.readFile(filePath, 'utf8', (err, data) => {
    if (err) return res.status(404).send("File not found");
    res.send(data);
  });
});

app.post('/calculate', (req, res) => {
  const expression = req.body.expression;
  try {
    const result = eval(expression); 
    res.json({ result });
  } catch (e) {
    res.status(400).send('Invalid expression');
  }
});

app.post('/signup', (req, res) => {
  const { username, password } = req.body;
  const hashed = hashPassword(password); 
  console.log(`User: ${username}, Hashed Password: ${hashed}`);
  res.send('User created');
});

app.get('/token', (req, res) => {
  const token = generateToken(16); 
  res.send({ token });
});

app.listen(port, () => {
  console.log(`Vulnerable server running on http://localhost:${port}`);
});
