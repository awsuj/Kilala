import express, { Request, Response } from 'express';
import dotenv from 'dotenv';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.get('/', (req: Request, res: Response) => {
  res.send('Kilala LGU Web Admin Portal is active.');
});

app.listen(PORT, () => {
  console.log(`[web-admin]: LGU Web Portal running on port ${PORT}`);
});