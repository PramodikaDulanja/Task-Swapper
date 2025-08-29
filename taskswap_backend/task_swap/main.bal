import ballerina/http;
import ballerina/log;
import ballerina/sql;
import ballerinax/mysql;

// --- 1. DATABASE CONFIGURATION ---
// These variables will be automatically loaded from your Config.toml file.
configurable string host = ?;
configurable string user = ?;
configurable string password = ?;
configurable string database = ?;
configurable int port = ?;

// --- 2. DATABASE CLIENT INITIALIZATION ---
// This creates a shared, final client that connects to your MySQL database.
// The 'check' keyword handles any potential errors during connection.
final mysql:Client dbClient = check new (
    host = host,
    user = user,
    password = password,
    database = database,
    port = port
);

// --- 3. DATA TYPE DEFINITION ---
// This 'record' defines the structure of the data we expect to receive
// from your HTML signup form. The field names MUST match the JSON keys.
public type NewUser record {|
    string fullname;
    string email;
    string password;
    string role;
|};

// --- 4. THE HTTP SERVICE ---
// This service will listen on port 9090 for incoming HTTP requests.
service /api on new http:Listener(9090) {

    // This resource function handles POST requests to the URL: http://localhost:9090/api/signup
    resource function post signup(@http:Payload NewUser newUser) returns http:Created|http:InternalServerError|http:Conflict {

        // In a real application, you MUST hash the password before saving it.
        // For now, we will save it as plain text for simplicity.

        // This is the SQL query to insert a new user into the database.
        // We use template strings `${...}` to safely insert data and prevent SQL injection.
        sql:ParameterizedQuery query = `
            INSERT INTO users (fullName, email, password, role)
            VALUES (${newUser.fullname}, ${newUser.email}, ${newUser.password}, ${newUser.role})
        `;

        // Execute the query using our database client.
        var executionResult = dbClient->execute(query);

        // Check if the execution was successful or if there was an error.
        if executionResult is sql:ExecutionResult {
            // Success! Log a message and return a "201 Created" response.
            log:printInfo("Successfully created a new user", email = newUser.email);
            return http:CREATED;
        } else {
            // An error occurred.
            log:printError("Error creating user", executionResult, email = newUser.email);

            // Check if it's a duplicate entry error (because email must be unique).
            if executionResult.message().includes("Duplicate entry") {
                // Return a "409 Conflict" which is more specific than a general error.
                return http:CONFLICT;
            }

            // For any other database error, return a "500 Internal Server Error".
            return http:INTERNAL_SERVER_ERROR;
        }
    }
}

