import mysql from 'mysql2/promise';

const config = {
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    port: process.env.DB_PORT ? Number(process.env.DB_PORT) : 3306,
    connectTimeout: 30000,
    xApiKey: process.env.X_API_KEY
};

export async function lambdaHandler(event, context) {
    try {
        const headers = event.headers || {};
        const apiHeaderKey = headers["x-api-key"] || "";

        if (!apiHeaderKey){
            return { statusCode: 401, body: JSON.stringify({ message: 'API key is required' }) };
        }

        if (apiHeaderKey != config.xApiKey){
            return { statusCode: 401, body: JSON.stringify({ message: 'API key is invalid' }) };
        }

        const body = JSON.parse(event.body || '{}');
        const cpf = body.cpf;

        if (!cpf) {
            return { statusCode: 400, body: JSON.stringify({ message: 'CPF is required' }) };
        }

        // Create a connection to MySQL
        const connection = await mysql.createConnection(config);

        // Execute the query to check if the user exists
        const [rows] = await connection.execute('SELECT 1 FROM Customer WHERE DocumentNumber = ?', [cpf]);

        // Close the connection
        await connection.end();

        if (rows.length > 0) {
            return { statusCode: 200, body: JSON.stringify({ message: 'User authenticated' }) };
        } else {
            return { statusCode: 401, body: JSON.stringify({ message: 'User not found' }) };
        }
    } catch (error) {
        return { statusCode: 500, body: JSON.stringify({ message: 'Internal server error', error: error.message }) };
    }
}
