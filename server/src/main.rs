//Rocket stuff
#[macro_use] extern crate rocket;

use rocket::futures::TryFutureExt;
use rocket::http::Status;
use rocket::request::{FromRequest, Outcome};
use rocket::serde::{json::Json, Deserialize, Serialize};
use rocket::Request;
//Serde json stuff
use serde_json::json;
//CouchDB stuff
use couch_rs::{document::TypedCouchDocument, Client};
use couch_rs::types::find::FindQuery;
use couch_rs::document::DocumentCollection;
//RNGs for session tokens
use rand::prelude::*;
use rand_chacha::ChaCha20Rng;
//Crypto libraries for hashing
use argon2::{
    password_hash::{
        rand_core::OsRng,
        PasswordHash, PasswordHasher, PasswordVerifier, SaltString
    },
    Argon2
};
//Token expiry stuff
use chrono::{Duration, Utc};
//Json web tokens
use jsonwebtoken::{encode, Algorithm, EncodingKey, Header};
//Sends request to apple
use reqwest::header::{HeaderMap, HeaderValue, AUTHORIZATION};
//Security stuff
use regex::Regex;
use std::fs::File;
use std::{env, fs};
use std::ffi::FromBytesUntilNulError;
//Error handling
use anyhow::{Context, Result};
//Post ids
use uuid::{uuid, Uuid};



#[derive(Debug, FromForm, Deserialize)]
#[serde(crate = "rocket::serde")]
struct SignUpUser {
    email: String,
    password: String,
    name: String,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
struct User{
    _rev: String,
    _id: String,
    user_id: i32,
    token_hashed: String,
    token_expiry: i64,
    email: String,
    password_hashed: String,
    name: String
}

impl Default for User{
    fn default() -> User {
        User { 
            _rev: String::new(), 
            _id: String::new(), 
            user_id: 0, 
            token_hashed: String::new(),
            token_expiry: 0,
            email: String::new(), 
            password_hashed: String::new(), 
            name: String::new(),
        }
    }
}

impl TypedCouchDocument for User{
    fn get_id(&self) -> couch_rs::Cow<str> {
        couch_rs::Cow::Borrowed(&self._id)
    }
    fn set_id(&mut self, id: &str) {
        self._id = id.to_string();
    }
    fn get_rev(&self) -> couch_rs::Cow<str> {
        couch_rs::Cow::Borrowed(&self._rev)
    }
    fn set_rev(&mut self, rev: &str) {
        self._rev = rev.to_string();
    }
    fn merge_ids(&mut self, other: &Self) {
        self._id = other._id.clone();
        self._rev = other._rev.clone();
    }
}

#[derive(Serialize, Deserialize, Debug)]
struct Run{
    distance: f32,
    avg_pace: f32,
    time: f32,
    start_time: i64,
    lat: f64,
    lon: f64,
}

#[derive(Serialize, Deserialize, Debug)]
struct ReturnRun{
    distance: f32,
    avg_pace: f32,
    time: f32,
    start_time: i64,
    locality: String,
}

#[derive(Serialize, Deserialize, Debug)]
struct ServerRun{
    _id: String,
    _rev: String,
    user_id: i32,
    distance: f32,
    avg_pace: f32,
    time: f32,
    start_time: i64,
    locality: String,
}
impl Default for ServerRun{
    fn default() -> ServerRun {
        ServerRun { 
            _rev: String::new(), 
            _id: String::new(), 
            user_id: 0, 
            distance: 0.0,
            avg_pace: 0.0,
            time: 0.0,
            start_time: 0,
            locality: String::new(),
        }
    }
}
impl TypedCouchDocument for ServerRun{
    fn get_id(&self) -> couch_rs::Cow<str> {
        couch_rs::Cow::Borrowed(&self._id)
    }
    fn set_id(&mut self, id: &str) {
        self._id = id.to_string();
    }
    fn get_rev(&self) -> couch_rs::Cow<str> {
        couch_rs::Cow::Borrowed(&self._rev)
    }
    fn set_rev(&mut self, rev: &str) {
        self._rev = rev.to_string();
    }
    fn merge_ids(&mut self, other: &Self) {
        self._id = other._id.clone();
        self._rev = other._rev.clone();
    }
}

#[derive(Serialize, Deserialize, Debug)]
struct RunID {
    start_time: i64,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
struct UserIdCounter{
    _id: String,
    _rev: String,
    metadata_name: String,
    current_uid: i32,
}
impl TypedCouchDocument for UserIdCounter{
    fn get_id(&self) -> couch_rs::Cow<str> {
        couch_rs::Cow::Borrowed(&self._id)
    }
    fn set_id(&mut self, id: &str) {
        self._id = id.to_string();
    }
    fn get_rev(&self) -> couch_rs::Cow<str> {
        couch_rs::Cow::Borrowed(&self._rev)
    }
    fn set_rev(&mut self, rev: &str) {
        self._rev = rev.to_string();
    }
    fn merge_ids(&mut self, other: &Self) {
        self._id = other._id.clone();
        self._rev = other._rev.clone();
    }
}

fn convert_u32s_to_u8s_vec(u32_array: &Vec<u32>) -> Vec<u8> {
    let mut u8_vec = Vec::with_capacity(u32_array.len() * 4);
    for &num in u32_array.iter() {
        let bytes = num.to_le_bytes();
        u8_vec.extend_from_slice(&bytes);
    }
    u8_vec
}
fn combine_u32_to_u128(arr: [u32; 4]) -> u128 {
    // Ensure the array has exactly 4 elements
    assert_eq!(arr.len(), 4);

    // Combine the four u32 values into a single u128
    let mut result: u128 = 0;
    result |= (arr[0] as u128) << 96;
    result |= (arr[1] as u128) << 64;
    result |= (arr[2] as u128) << 32;
    result |= arr[3] as u128;

    result
}
fn split_u128_to_u32(val: u128) -> [u32; 4] {
    // Extract each u32 value from the u128
    let part1 = ((val >> 96) & 0xFFFFFFFF) as u32;
    let part2 = ((val >> 64) & 0xFFFFFFFF) as u32;
    let part3 = ((val >> 32) & 0xFFFFFFFF) as u32;
    let part4 = (val & 0xFFFFFFFF) as u32;

    [part1, part2, part3, part4]
}

struct AuthorizationHeader(String);
#[rocket::async_trait]
impl<'r> FromRequest<'r> for AuthorizationHeader{
    type Error = ();

    async fn from_request(request: &'r Request<'_>) -> Outcome<Self, Self::Error> {
        match request.headers().get_one("Authorization"){
            Some(header_value) => Outcome::Success(AuthorizationHeader(header_value.to_string())),
            None => Outcome::Error((Status::BadRequest, ()))
        }
    }
}

#[derive(Debug, Serialize, Deserialize)]
struct AppleClaims {
    iss: String,
    iat: i64,
    exp: i64,
}

#[allow(non_snake_case)]
#[derive(Debug, Deserialize)]
struct TokenResponse {
    accessToken: String,
    expiresInSeconds: u32,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
struct AppleAccessToken {
    _id: String,
    _rev: String,
    metadata_name: String,
    access_token: String,
    expires_at_utc: i64,
}
impl TypedCouchDocument for AppleAccessToken{
    fn get_id(&self) -> couch_rs::Cow<str> {
        couch_rs::Cow::Borrowed(&self._id)
    }
    fn set_id(&mut self, id: &str) {
        self._id = id.to_string();
    }
    fn get_rev(&self) -> couch_rs::Cow<str> {
        couch_rs::Cow::Borrowed(&self._rev)
    }
    fn set_rev(&mut self, rev: &str) {
        self._rev = rev.to_string();
    }
    fn merge_ids(&mut self, other: &Self) {
        self._id = other._id.clone();
        self._rev = other._rev.clone();
    }
}


#[derive(Serialize, Deserialize, Debug, Clone)]
struct ServerGroup {
    _id: String,
    _rev: String,
    group_id: i32,
	name: String,
	owner: i32,
	users: Vec<i32>,
}
impl TypedCouchDocument for ServerGroup{
    fn get_id(&self) -> couch_rs::Cow<str> {
        couch_rs::Cow::Borrowed(&self._id)
    }
    fn set_id(&mut self, id: &str) {
        self._id = id.to_string();
    }
    fn get_rev(&self) -> couch_rs::Cow<str> {
        couch_rs::Cow::Borrowed(&self._rev)
    }
    fn set_rev(&mut self, rev: &str) {
        self._rev = rev.to_string();
    }
    fn merge_ids(&mut self, other: &Self) {
        self._id = other._id.clone();
        self._rev = other._rev.clone();
    }
}
impl Default for ServerGroup{
    fn default() -> ServerGroup {
        ServerGroup { 
                _rev: String::new(), 
                _id: String::new(),
                name: String::new(),
                group_id: 0,
                owner: 0,
                users: Vec::new(),
        }
    }
}
#[derive(Debug, Serialize, Deserialize)]
struct ServerGroupRequest {
    _id: String,
    _rev: String,
	name: String,
	group_id: i32,
	owner_name: String,
	invited_user: i32,
}
impl TypedCouchDocument for ServerGroupRequest{
    fn get_id(&self) -> couch_rs::Cow<str> {
        couch_rs::Cow::Borrowed(&self._id)
    }
    fn set_id(&mut self, id: &str) {
        self._id = id.to_string();
    }
    fn get_rev(&self) -> couch_rs::Cow<str> {
        couch_rs::Cow::Borrowed(&self._rev)
    }
    fn set_rev(&mut self, rev: &str) {
        self._rev = rev.to_string();
    }
    fn merge_ids(&mut self, other: &Self) {
        self._id = other._id.clone();
        self._rev = other._rev.clone();
    }
}
impl Default for ServerGroupRequest{
    fn default() -> ServerGroupRequest {
        ServerGroupRequest { 
                _rev: String::new(), 
                _id: String::new(),
                name: String::new(),
                group_id: 0,
                owner_name: String::new(),
                invited_user: 0,
        }
    }
}
#[derive(Debug, Serialize, Deserialize)]
struct GroupRequest {
	name: String,
	group_id: i32,
	owner_name: String,
}
#[derive(Debug, Serialize, Deserialize)]
struct GroupRequestResponse {
    group_id: i32,
    response: i32,
}


#[derive(Debug, Serialize, Deserialize)]
struct AddGroupRequest{
    email: String,
    group_id: i32,
}

#[derive(Serialize, Deserialize, Debug)]
struct CreationGroup {
    name: String,
}

#[derive(Debug, Serialize, Deserialize)]
struct GetGroupResponse {
    onwer_or_not: i32,
    owner_name: String,
    group_id: i32,
    group_name: String,
    usernames: Vec<String>,
}

#[derive(Debug, Serialize, Deserialize)]
struct GroupRun {
    username: String,
    runs: Vec<ReturnRun>,
}

#[derive(Debug, Serialize, Deserialize)]
struct GroupID {
    group_id: i32,
}
#[derive(Debug, Serialize, Deserialize)]
struct ServerRunInvite {
    _id: String,
    _rev: String,
    creator_id: i32,
    group_id: i32,
    time: i64,
    place: String,
    notes: String,    
}
impl TypedCouchDocument for ServerRunInvite{
    fn get_id(&self) -> couch_rs::Cow<str> {
        couch_rs::Cow::Borrowed(&self._id)
    }
    fn set_id(&mut self, id: &str) {
        self._id = id.to_string();
    }
    fn get_rev(&self) -> couch_rs::Cow<str> {
        couch_rs::Cow::Borrowed(&self._rev)
    }
    fn set_rev(&mut self, rev: &str) {
        self._rev = rev.to_string();
    }
    fn merge_ids(&mut self, other: &Self) {
        self._id = other._id.clone();
        self._rev = other._rev.clone();
    }
}
impl Default for ServerRunInvite{
    fn default() -> ServerRunInvite {
        ServerRunInvite { 
                _rev: String::new(), 
                _id: String::new(),
                creator_id: 0,
                group_id: 0,
                time: 0,
                place: String::new(),
                notes: String::new(), 
        }
    }
}

#[derive(Debug, Serialize, Deserialize)]
struct RunInvite {
    group_id: i32,
    time: i64,
    place: String,
    notes: String,
}

#[derive(Debug, Serialize, Deserialize)]
struct ReturnRunInvite {
    creator: String,
    time: i64,
    place: String,
    notes: String,
}

trait Validated {
    fn validated(&self) -> Result<(), String>;
}

impl Validated for str {
    fn validated(&self) -> Result<(), String> {
        let group_id_regex = Regex::new(r"^[a-zA-Z0-9_]+$").unwrap();
        if group_id_regex.is_match(self) {
            Ok(())
        } else {
            Err(format!("Invalid group_id: {}", self))
        }
    }
}

#[derive(Debug, Serialize, Deserialize)]
struct Post {
    comment: String,
    run: Run,
}

#[derive(Debug, Serialize, Deserialize)]
struct ServerPost {
    _id: String,
    _rev: String,
    uuid: String,
    run: Run,
    comment: String,
    username: String,
}
impl TypedCouchDocument for ServerPost{
    fn get_id(&self) -> couch_rs::Cow<str> {
        couch_rs::Cow::Borrowed(&self._id)
    }
    fn set_id(&mut self, id: &str) {
        self._id = id.to_string();
    }
    fn get_rev(&self) -> couch_rs::Cow<str> {
        couch_rs::Cow::Borrowed(&self._rev)
    }
    fn set_rev(&mut self, rev: &str) {
        self._rev = rev.to_string();
    }
    fn merge_ids(&mut self, other: &Self) {
        self._id = other._id.clone();
        self._rev = other._rev.clone();
    }
}

struct LatLon {
    lat: f32,
    lon: f32,
}

fn get_apple_token() -> Result<String, ()>{
    let header = Header { kid: Some("6TXCW9YLVD".to_owned()), alg: Algorithm::ES256, ..Default::default() };
    let claims = AppleClaims {iss: "BAXHH9RS5H".to_string(), iat: Utc::now().timestamp(), exp: Utc::now().timestamp() + (30 * 60)};
        
    let token = match encode(&header, &claims, &EncodingKey::from_ec_pem(&env::var("apple_key").unwrap().as_bytes()).map_err(|_| ())?) {
        Ok(t) => t,
        Err(_) => return Result::Err(()),
    };
    Result::Ok(token)
}

async fn get_maps_auth_token(db_client: &Client) -> Result<String, ()>{
    let db = db_client.db("abrametadata").await.map_err(|_| ())?;
    let mut query = FindQuery::find_all();
    query.selector = json!({"metadata_name": "access_token"});

    let token_metadata: DocumentCollection<AppleAccessToken> = db.find(&query).await.map_err(|_| ())?;
    
    assert_eq!(token_metadata.total_rows, 1);

    if Utc::now().timestamp() < token_metadata.rows[0].expires_at_utc {
        return Result::Ok(token_metadata.rows[0].clone().access_token);
    }
    let mut token_metadata: AppleAccessToken = token_metadata.rows[0].clone();

    let token = get_apple_token()?;

    // Construct the URL and headers
    let url = "https://maps-api.apple.com/v1/token";
    let client = reqwest::Client::new();
    let mut headers = HeaderMap::new();
    headers.insert(AUTHORIZATION, HeaderValue::from_str(&format!("Bearer {}", token)).map_err(|_| ())?);

    // Send the request
    let response = client.get(url)
        .headers(headers)
        .send()
        .await.map_err(|_| ())?;

    // Parse JSON response
    let token_response: TokenResponse = response.json().await.map_err(|_| ())?;
    token_metadata.access_token = token_response.accessToken;
    token_metadata.expires_at_utc = token_response.expiresInSeconds as i64 + Utc::now().timestamp();
    //We have a token either way, if we save it good, if we can't well just get a new one next time
    let _ = db.save(&mut token_metadata).await;

    Result::Ok(token_metadata.access_token)
}

fn extract_field(json: &str, field: &str) -> Option<String> {
    let field_pattern = format!("\"{}\":\"", field);
    if let Some(start) = json.find(&field_pattern) {
        let start = start + field_pattern.len();
        if let Some(end) = json[start..].find('"') {
            return Some(json[start..start + end].to_string());
        }
    }
    None
}


async fn reverse_geocode(token: &str, lat: f64, lon: f64) -> Result<String, ()> {
    let url = format!("https://maps-api.apple.com/v1/reverseGeocode?loc={},{}", lat, lon);

    let client = reqwest::Client::new();
    let resp = match client.get(&url)
        .header("Authorization", HeaderValue::from_str(&format!("Bearer {}", token)).map_err(|_| ())?)
        .send()
        .await
    {
        Ok(resp) => resp,
        Err(_) => return Result::Err(())
    };

    let body = resp.text().await.map_err(|_| ())?;

    let mut locality = extract_field(&body, "locality").ok_or(())?;
    if let Some(administrative_area_code) = extract_field(&body, "administrativeAreaCode"){
        if administrative_area_code == "DC" {
            locality = format!("{x} {y}", x = locality, y = administrative_area_code);
        }
    }
    if locality.len() > 0 {
        return Result::Ok(locality)
    }
    Result::Err(())
}


fn parse_bearer_token(token: &str) -> Result<(u128, i32), ()> {
    let prefix = "Bearer ";
    if token.starts_with(prefix) {
        let token = token.trim_start_matches(prefix);
        let parts: Vec<&str> = token.split(':').collect();
        if parts.len() == 2 {
            let session_id = parts[0].parse::<u128>().map_err(|_| ())?;
            let user_id = parts[1].parse::<i32>().map_err(|_| ())?;
            return Result::Ok((session_id, user_id));
        }
    }
    Result::Err(())
}
async fn authorize_user(token: &[u32; 4], user_id: i32) -> Result<User, Status>{
        //Connect and open the db
        let client = Client::new("http://localhost:5984", &env::var("database_username").unwrap(), &env::var("database_password").unwrap()).map_err(|_| Status::InternalServerError)?;
        let db = client.db("abrausers").await.map_err(|_| Status::InternalServerError)?;
    
        //Grab the user from the server
        let mut query = FindQuery::find_all();
        query.selector = json!({"user_id": user_id});

        let user_docs: DocumentCollection<User> = db.find(&query).await.map_err(|_| Status::InternalServerError)?;

        //Ensure that there are no two people with the same uid
        if user_docs.total_rows > 1{
            return Result::Err(Status::InternalServerError);
        }
        
        if user_docs.total_rows == 0{
            return Result::Err(Status::Unauthorized);
        }

        //If this user's token has expired, don't go through the trouble of hashing it
        if Utc::now().timestamp() >= user_docs.rows[0].token_expiry {
            return Result::Err(Status::Unauthorized);
        }
        //Hash the token so we can compare it against the server's
        let parsed_hash = PasswordHash::new(&user_docs.rows[0].token_hashed).map_err(|_| Status::InternalServerError)?;
        if Argon2::default().verify_password(&convert_u32s_to_u8s_vec(&token.to_vec()), &parsed_hash).is_ok(){
            return Result::Ok(user_docs.rows[0].clone());
        }else{
            return Result::Err(Status::Unauthorized);
        }
}

async fn get_next_uid(db_client: &Client) -> Result<i32, Status>{
    let db = db_client.db("abrametadata").await.map_err(|_| Status::InternalServerError)?;
    let mut query = FindQuery::find_all();
    query.selector = json!({"metadata_name": "current_uid"});

    let current_uid_metadata: DocumentCollection<UserIdCounter> = db.find(&query).await.map_err(|_| Status::InternalServerError)?;

    assert_eq!(current_uid_metadata.total_rows, 1);

    let mut current_uid_metadata_counter = current_uid_metadata.rows[0].clone();
    let uid = current_uid_metadata_counter.current_uid;

    current_uid_metadata_counter.current_uid += 1;

    if let Ok(_) = db.save(&mut current_uid_metadata_counter).await {
        return Result::Ok(uid);
    }else{
        return Result::Err(Status::InternalServerError);
    }
}

async fn get_next_gid(db_client: &Client) -> Result<i32, Status>{
    let db = db_client.db("abrametadata").await.map_err(|_| Status::InternalServerError)?;
    let mut query = FindQuery::find_all();
    query.selector = json!({"metadata_name": "current_gid"});

    let current_gid_metadata: DocumentCollection<UserIdCounter> = db.find(&query).await.map_err(|_| Status::InternalServerError)?;

    assert_eq!(current_gid_metadata.total_rows, 1);

    let mut current_gid_metadata_counter = current_gid_metadata.rows[0].clone();
    let gid = current_gid_metadata_counter.current_uid;

    current_gid_metadata_counter.current_uid += 1;

    if let Ok(_) = db.save(&mut current_gid_metadata_counter).await {
        return Result::Ok(gid);
    }else{
        return Result::Err(Status::InternalServerError);
    }
}

async fn store_user(sign_up_user: SignUpUser) -> Result<String, Status>{
    //Connect and open the db
    let client = Client::new("http://localhost:5984", &env::var("database_username").unwrap(), &env::var("database_password").unwrap()).context("Failed to create client").map_err(|e| { eprintln!("Error: {:?}", e); Status::InternalServerError })?;
    let db = client.db("abrausers").await.context("Failed to connect to abrausers database").map_err(|e| { eprintln!("Error: {:?}", e); Status::InternalServerError })?;
    //Ensure that there are no previous users with that same email
    //Run a mango query for the user's email
    let mut query = FindQuery::find_all();
    query.selector = json!({"email": sign_up_user.email.to_lowercase()});

    let user_docs: DocumentCollection<User> = db.find(&query).await.context("Failed to find user by email").map_err(|e| { eprintln!("Error: {:?}", e); Status::InternalServerError })?;
    //Ensure that there are no two people with the same email
    if user_docs.total_rows != 0{
        return Result::Err(Status::UnprocessableEntity);
    }
    //Run a mango query for the user's email
    let mut query = FindQuery::find_all();
    query.selector = json!({"name": sign_up_user.name});
    
    let user_docs: DocumentCollection<User> = db.find(&query).await.context("Failed to find user by name").map_err(|e| { eprintln!("Error: {:?}", e); Status::InternalServerError })?;
    //Ensure that there are no two people with the same email
    if user_docs.total_rows != 0{
        return Result::Err(Status::Conflict);
    }

    //Get the salt
    let salt = SaltString::generate(&mut OsRng);
    //Hash the password with the salt using SHA3 (Keccak)
    let argon2 = Argon2::default();
    let hashed_password = argon2.hash_password(&sign_up_user.password.as_bytes(), &salt).map_err(|e| { eprintln!("Error: {:?}", e); Status::InternalServerError })?.to_string();
    //Generate a session token
    let mut token_rng = ChaCha20Rng::from_entropy();
    let mut token: [u32; 4] = [0; 4];
    token_rng.fill(&mut token);
    //Get a session token salt
    let sesh_salt = SaltString::generate(&mut OsRng);
    //Hash the session token
    let session_hash = argon2.hash_password(&&convert_u32s_to_u8s_vec(&token.to_vec()), &sesh_salt).map_err(|e| { eprintln!("Error: {:?}", e); Status::InternalServerError })?.to_string();
    //Expire the token at this time 
    let token_expiry = Utc::now().timestamp() + Duration::days(3).num_seconds();
    //Create the user object
    let uid = get_next_uid(&client).await.map_err(|e| { eprintln!("Error: {:?}", e); Status::InternalServerError })?;

    let mut user = User{
        user_id: uid,
        token_hashed: 
        session_hash,
        token_expiry: token_expiry,
        email: sign_up_user.email.to_lowercase(),
        password_hashed: hashed_password,
        name: sign_up_user.name,
        ..Default::default()
    };
    //Store the user object to the db
    if let Ok(_) = db.create(&mut user).await{
        return Result::Ok(format!("{x}:{y}", x=combine_u32_to_u128(token), y=user.user_id));
    }else{
        println!("error saving");
        return Result::Err(Status::InternalServerError);
    }
    
}


//Takes in a sign_up_user and returns a session token
async fn check_user(sign_up_user: SignUpUser) -> Result<String, Status>{
    //Connect and open t0he db
    let client = Client::new("http://localhost:5984", &env::var("database_username").unwrap(), &env::var("database_password").unwrap()).map_err(|_| Status::InternalServerError)?;
    let db = client.db("abrausers").await.map_err(|_| Status::InternalServerError)?;
    //Run a mango query for the user's email
    let mut query = FindQuery::find_all();
    query.selector = json!({"email": sign_up_user.email.to_lowercase()});

    let user_docs: DocumentCollection<User> = db.find(&query).await.map_err(|_| Status::InternalServerError)?;
    //Ensure that there are no two people with the same email
    if user_docs.total_rows != 1{
        return Result::Err(Status::InternalServerError);
    }
    let mut user_doc = user_docs.rows[0].clone();
    //Hash the password and the salt and verify.
    let parsed_hash = PasswordHash::new(&user_doc.password_hashed).map_err(|_| Status::InternalServerError)?;
    if !(Argon2::default().verify_password(sign_up_user.password.as_bytes(), &parsed_hash).is_ok()) {
        return Result::Err(Status::Unauthorized);
    }
    //Generate a session token
    let mut token_rng = ChaCha20Rng::from_entropy();
    let mut token: [u32; 4] = [0; 4];
    token_rng.fill(&mut token);
    //Get a session token salt
    let sesh_salt = SaltString::generate(&mut OsRng);
    //Hash the session token
    let argon2 = Argon2::default();
    let session_hash = argon2.hash_password(&&convert_u32s_to_u8s_vec(&token.to_vec()), &sesh_salt).map_err(|_| Status::InternalServerError)?.to_string();
    user_doc.token_hashed = session_hash;
    //Expire the token after an amount of time
    user_doc.token_expiry = Utc::now().timestamp() + Duration::days(3).num_seconds();
    if let Ok(_) = db.save(&mut user_doc).await {
        return Result::Ok(format!("{x}:{y}", x=combine_u32_to_u128(token), y=user_doc.user_id));
    }else{
        return Result::Err(Status::InternalServerError);
    }
}

async fn store_run(run: Run, user: User) -> Result<String, Status>{
    //Connect to the db
    let client = Client::new("http://localhost:5984", &env::var("database_username").unwrap(), &env::var("database_password").unwrap()).map_err(|_| Status::InternalServerError)?;
    //Get the token for reverse geocoding
    let maps_auth_token = get_maps_auth_token(&client).await.map_err(|_| Status::InternalServerError)?;
    //Reverse geocode
    let locality = reverse_geocode(&maps_auth_token, run.lat, run.lon).await.map_err(|_| Status::InternalServerError)?;
    //Open the runs database
    let db = client.db("abraruns").await.map_err(|_| Status::InternalServerError)?;
    let mut run = ServerRun{
        user_id: user.user_id,
        distance: run.distance,
        avg_pace: run.avg_pace,
        time: run.time,
        start_time: run.start_time,
        locality: locality.clone(),
        ..Default::default()
    };

    if let Ok(_) = db.create(&mut run).await{
        return Result::Ok(locality);
    }else{
        return Result::Err(Status::InternalServerError);
    }
}

async fn get_runs_from_server(user: User) -> Result<Json<Vec<ReturnRun>>, Status>{
    //Connect and open the db
    let client = Client::new("http://localhost:5984", &env::var("database_username").unwrap(), &env::var("database_password").unwrap()).map_err(|_| Status::InternalServerError)?;
    let db = client.db("abraruns").await.map_err(|_| Status::InternalServerError)?;

    //Run a mango query for the user id
    let mut query = FindQuery::find_all();
    query.selector = json!({"user_id": user.user_id});
    
    let mut num_runs_on_page = 1;
    let mut runs: Vec<ReturnRun> = Vec::new();

    while num_runs_on_page != 0{
        let run_docs: DocumentCollection<ServerRun> = db.find(&query).await.map_err(|_| Status::InternalServerError)?;

        for run in run_docs.rows{
            let run: ReturnRun = ReturnRun{
                distance: run.distance,
                avg_pace: run.avg_pace,
                time: run.time,
                start_time: run.start_time,
                locality: run.locality,
            };
            runs.push(run);
        }
        num_runs_on_page = run_docs.total_rows;
        if let Some(new_bookmark) = run_docs.bookmark {
            query.bookmark = Some(new_bookmark.clone());
        }else{
            break;
        }
    }
    


    Result::Ok(Json(runs))

}

async fn get_runs_from_server_with_name(user: User) -> Result<GroupRun, Status>{
    let client = Client::new("http://localhost:5984", &env::var("database_username").unwrap(), &env::var("database_password").unwrap()).map_err(|_| Status::InternalServerError)?;
    let db = client.db("abraruns").await.map_err(|_| Status::InternalServerError)?;

    //Run a mango query for the user id
    let mut query = FindQuery::find_all();
    query.selector = json!({"user_id": user.user_id});
    
    let mut num_runs_on_page = 1;
    let mut runs: GroupRun =  GroupRun {
        username: user.name, 
        runs: Vec::new(),
    };

    while num_runs_on_page != 0{
        let run_docs: DocumentCollection<ServerRun> = db.find(&query).await.map_err(|_| Status::InternalServerError)?;

        for run in run_docs.rows{
            let run: ReturnRun = ReturnRun{
                distance: run.distance,
                avg_pace: run.avg_pace,
                time: run.time,
                start_time: run.start_time,
                locality: run.locality,
            };
            runs.runs.push(run);
        }
        num_runs_on_page = run_docs.total_rows;
        if let Some(new_bookmark) = run_docs.bookmark {
            query.bookmark = Some(new_bookmark.clone());
        }else{
            break;
        }
    }
    
    Result::Ok(runs)

}
async fn create_group_on_server(user: User, group_data: CreationGroup) -> Result<Status, Status>{
    //Connect and open the db
    let client = Client::new("http://localhost:5984", &env::var("database_username").unwrap(), &env::var("database_password").unwrap()).map_err(|_| Status::InternalServerError)?;
    let group_id = get_next_gid(&client).await.map_err(|_| Status::InternalServerError)?;
    let db = client.db("abragroups").await.map_err(|_| Status::InternalServerError)?;

    let mut query = FindQuery::find_all();
    query.selector = json!({"owner": user.user_id});

    let user_groups: DocumentCollection<ServerGroup> = db.find(&query).await.map_err(|_| Status::InternalServerError)?;

    if user_groups.total_rows > 1{
        return Result::Err(Status::Forbidden);
    }


    let mut group = ServerGroup {
        name: group_data.name,
        owner: user.user_id,
        group_id: group_id,
        ..Default::default()
    };

    if let Ok(_) = db.create(&mut group).await{
        return Result::Ok(Status::Ok);
    }else{
        return Result::Err(Status::InternalServerError);
    }

}
//Result used to keep consistent error haandling between the functions
async fn invite_user(owner: User, user_group_data: AddGroupRequest) -> Result<Status, Status>{
    let client = Client::new("http://localhost:5984", &env::var("database_username").unwrap(), &env::var("database_password").unwrap()).map_err(|_| Status::InternalServerError)?;
    let db = client.db("abragroups").await.map_err(|_| Status::InternalServerError)?;
    let mut query = FindQuery::find_all();
    query.selector = json!({"group_id": user_group_data.group_id});

    let group_docs: DocumentCollection<ServerGroup> = db.find(&query).await.map_err(|_| Status::InternalServerError)?;

    if group_docs.total_rows != 1{
        return Result::Err(Status::InternalServerError);
    }

    if group_docs[0].owner != owner.user_id {
        return Result::Err(Status::Unauthorized);
    }

    if group_docs[0].users.len() >= 5 {
        return Result::Err(Status::Forbidden);
    }
    //Get the user; we need the owner's name for the req

    let db = client.db("abrausers").await.map_err(|_| Status::InternalServerError)?;

    //Run a mango query for the user's email
    let mut query = FindQuery::find_all();
    query.selector = json!({"email": user_group_data.email.to_lowercase()});

    let user_docs: DocumentCollection<User> = db.find(&query).await.map_err(|_| Status::InternalServerError)?;
    //Ensure that there are no two people with the same email
    if user_docs.total_rows != 1{
        return Result::Err(Status::InternalServerError);
    }
    //Assemble the group request

    let mut request = ServerGroupRequest{
        name: group_docs[0].name.clone(),
        group_id: user_group_data.group_id,
        owner_name: owner.name,
        invited_user: user_docs[0].user_id,
        ..Default::default()
    };

    let db = client.db("abragrouprequests").await.map_err(|_| Status::InternalServerError)?;
    if let Ok(_) = db.create(&mut request).await{
        return Result::Ok(Status::Ok);
    }else{
        return Result::Err(Status::InternalServerError);
    }
}

async fn get_group_requests(user: User) -> Result<Json<Vec<GroupRequest>>, Status>{
    let client = Client::new("http://localhost:5984", &env::var("database_username").unwrap(), &env::var("database_password").unwrap()).map_err(|_| Status::InternalServerError)?;
    let db = client.db("abragrouprequests").await.map_err(|_| Status::InternalServerError)?;

    let mut query = FindQuery::find_all();
    query.selector = json!({"invited_user": user.user_id});

    let group_request_docs: DocumentCollection<ServerGroupRequest> = db.find(&query).await.map_err(|_| Status::InternalServerError)?;

    let mut group_requests = Vec::new();

    for group_request in group_request_docs.rows {
        group_requests.push(
            GroupRequest { name: group_request.name, group_id: group_request.group_id, owner_name: group_request.owner_name }
        )
    }

    Result::Ok(Json(group_requests))
}

async fn group_request_response(user: User, group_response: GroupRequestResponse) -> Result<Status, Status>{
    let client = Client::new("http://localhost:5984", &env::var("database_username").unwrap(), &env::var("database_password").unwrap()).map_err(|_| Status::InternalServerError)?;
    let db = client.db("abragrouprequests").await.map_err(|_| Status::InternalServerError)?;

    let mut query = FindQuery::find_all();
    query.selector = json!({"invited_user": user.user_id, "group_id": group_response.group_id});

    let group_request_docs: DocumentCollection<ServerGroupRequest> = db.find(&query).await.map_err(|_| Status::InternalServerError)?;

    if group_request_docs.rows.len() == 0 {
        //Never had invite
        return Result::Err(Status::InternalServerError);
    }

    for group_request in group_request_docs.rows {
        db.remove(&group_request).await;
    }
    if group_response.response == 0{
        return Result::Ok(Status::Ok);
    }
    let db = client.db("abragroups").await.map_err(|_| Status::InternalServerError)?;

    let mut query = FindQuery::find_all();
    query.selector = json!({"group_id": group_response.group_id});

    let group_docs: DocumentCollection<ServerGroup> = db.find(&query).await.map_err(|_| Status::InternalServerError)?;

    if group_docs.total_rows != 1{
        return Result::Err(Status::InternalServerError);
    }
    let mut group_doc = group_docs.rows[0].clone();
    group_doc.users.push(user.user_id);

    if let Ok(_) = db.save(&mut group_doc).await {
        return Result::Ok(Status::Ok);
    }else{
        return Result::Err(Status::InternalServerError);
    }

}

async fn get_my_groups(user: User) -> Result<Json<Vec<GetGroupResponse>>, Status>{
    let client = Client::new("http://localhost:5984", &env::var("database_username").unwrap(), &env::var("database_password").unwrap()).map_err(|_| Status::InternalServerError)?;
    let db = client.db("abragroups").await.map_err(|_| Status::InternalServerError)?;

    let mut query = FindQuery::find_all();
    query.selector = json!({
        "$or": [
            {"users": {"$elemMatch": {"$eq": user.user_id}}},
            {"owner": user.user_id}
        ]
    });

    let group_docs: DocumentCollection<ServerGroup> = db.find(&query).await.map_err(|_| Status::InternalServerError)?;

    let mut my_groups = Vec::new();

    let db = client.db("abrausers").await.map_err(|_| Status::InternalServerError)?;

    for group in group_docs.rows{
        let mut users_names: Vec<String> = Vec::new();
        let mut user_ids: Vec<i32> = Vec::new();
        let mut owner_name: String = String::new();
        let mut owner_or_not: i32 = 0;
        if group.owner == user.user_id{
            owner_name = user.name.clone();
            owner_or_not = 1;
        }else{
            user_ids.push(group.owner);
        }
        user_ids.extend(group.users);
        let mut query = FindQuery::find_all();
        query.selector = json!({
            "user_id": {
                "$in": user_ids
            }
        });
        let group_user_docs: DocumentCollection<User> = db.find(&query).await.map_err(|_| Status::InternalServerError)?;

        for user in group_user_docs.rows {
            if user.user_id == group.owner {
                owner_name = user.name.clone();
            }else{
                users_names.push(user.name.clone());
            }
        }

        my_groups.push(GetGroupResponse{
            onwer_or_not: owner_or_not,
            owner_name: owner_name,
            group_id: group.group_id,
            group_name: group.name,
            usernames: users_names,
        })
    }



    Result::Ok(Json(my_groups))
        
}

async fn get_group_runs(user: User, group_id: i32) -> Result<Json<Vec<GroupRun>>, Status>{
    let client = Client::new("http://localhost:5984", &env::var("database_username").unwrap(), &env::var("database_password").unwrap()).map_err(|_| Status::InternalServerError)?;
    let db = client.db("abragroups").await.map_err(|_| Status::InternalServerError)?;
    let mut query = FindQuery::find_all();
    query.selector = json!({"group_id": group_id});

    let group_docs: DocumentCollection<ServerGroup> = db.find(&query).await.map_err(|_| Status::InternalServerError)?;

    if group_docs.total_rows != 1{
        return Result::Err(Status::Unauthorized);
    }

    if user.user_id != group_docs.rows[0].owner && !group_docs.rows[0].users.contains(&user.user_id) {
        return Result::Err(Status::Unauthorized);
    }

    let mut user_ids: Vec<i32> = Vec::new();
    user_ids.push(group_docs.rows[0].owner);
    user_ids.extend(group_docs.rows[0].users.clone());

    //Connect and open the db
    let client = Client::new("http://localhost:5984", &env::var("database_username").unwrap(), &env::var("database_password").unwrap()).map_err(|_| Status::InternalServerError)?;
    let db = client.db("abrausers").await.map_err(|_| Status::InternalServerError)?;
        
    //Grab the user from the server
    let mut query = FindQuery::find_all();
    query.selector = json!({
        "user_id": {
            "$in": user_ids
        }
    });
    let user_docs: DocumentCollection<User> = db.find(&query).await.map_err(|_| Status::InternalServerError)?;

    let mut users_runs: Vec<GroupRun> = Vec::new();
    
    for user in user_docs.rows{
        users_runs.push(get_runs_from_server_with_name(user).await.map_err(|_| Status::InternalServerError)?);
    }

    Result::Ok(Json(users_runs))
}

async fn new_run_invite(user: User, invite: RunInvite) -> Result<Status, Status> {
    let client = Client::new("http://localhost:5984", &env::var("database_username").unwrap(), &env::var("database_password").unwrap()).map_err(|_| Status::InternalServerError)?;
    let db = client.db("abragroups").await.map_err(|_| Status::InternalServerError)?;
    let mut query = FindQuery::find_all();
    query.selector = json!({"group_id": invite.group_id});

    let group_docs: DocumentCollection<ServerGroup> = db.find(&query).await.map_err(|_| Status::InternalServerError)?;

    //Make sure there aren't two groups with the same id
    if group_docs.total_rows != 1{
        return Result::Err(Status::Unauthorized);
    }

    if user.user_id != group_docs.rows[0].owner && !group_docs.rows[0].users.contains(&user.user_id) {
        return Result::Err(Status::Unauthorized);
    }

    let mut server_run_invite = ServerRunInvite {
        creator_id: user.user_id,
        group_id: invite.group_id,
        time: invite.time,
        place: invite.place,
        notes: invite.notes,
        ..Default::default()
    };

    let db = client.db("abraruninvites").await.map_err(|_| Status::InternalServerError)?;
    if let Ok(_) = db.create(&mut server_run_invite).await{
        return Result::Ok(Status::Ok);
    }else{
        return Result::Err(Status::InternalServerError);
    }

}

async fn get_run_invites(user: User, group_id: GroupID) -> Result<Json<Vec<ReturnRunInvite>>, Status> {
    let client = Client::new("http://localhost:5984", &env::var("database_username").unwrap(), &env::var("database_password").unwrap()).map_err(|_| Status::InternalServerError)?;
    let db = client.db("abragroups").await.map_err(|_| Status::InternalServerError)?;
    let mut query = FindQuery::find_all();
    query.selector = json!({"group_id": group_id.group_id});

    let group_docs: DocumentCollection<ServerGroup> = db.find(&query).await.map_err(|_| Status::InternalServerError)?;

    //Make sure there aren't two groups with the same id
    if group_docs.total_rows != 1{
        return Result::Err(Status::Unauthorized);
    }

    if user.user_id != group_docs.rows[0].owner && !group_docs.rows[0].users.contains(&user.user_id) {
        return Result::Err(Status::Unauthorized);
    }
    let db = client.db("abraruninvites").await.map_err(|_| Status::InternalServerError)?;

    let mut query = FindQuery::find_all();
    query.selector = json!({"group_id": group_id.group_id});

    let server_invites: DocumentCollection<ServerRunInvite> = db.find(&query).await.map_err(|_| Status::InternalServerError)?;

    let mut run_invites = Vec::new();

    for server_invite in server_invites.rows {
        if server_invite.time + Duration::hours(1).num_seconds() < Utc::now().timestamp() {
            db.remove(&server_invite).await;
            continue;
        }

        let db = client.db("abrausers").await.map_err(|_| Status::InternalServerError)?;

        let mut query = FindQuery::find_all();
        query.selector = json!({"user_id": server_invite.creator_id});

        let user_docs: DocumentCollection<User> = db.find(&query).await.map_err(|_| Status::InternalServerError)?;

        if user_docs.total_rows != 1 {
            return Result::Err(Status::Unauthorized);
        }

        run_invites.push(ReturnRunInvite {
            creator: user_docs[0].name.clone(),
            time: server_invite.time,
            place: server_invite.place,
            notes: server_invite.notes,
        })
    }

    Result::Ok(Json(run_invites))

}

async fn delete_account(user: User) -> Result<Status, Status> {
    //Connect and open the db
    let client = Client::new("http://localhost:5984", &env::var("database_username").unwrap(), &env::var("database_password").unwrap()).map_err(|_| Status::InternalServerError)?;
    let db = client.db("abrausers").await.map_err(|_| Status::InternalServerError)?;

    db.remove(&user).await;

    let db = client.db("abraruns").await.map_err(|_| Status::InternalServerError)?;
    let mut query = FindQuery::find_all();
    query.selector = json!({"user_id": user.user_id});

    let run_docs: DocumentCollection<ServerRun> = db.find(&query).await.map_err(|_| Status::InternalServerError)?;

    for run in run_docs.rows{
        db.remove(&run).await;
    }
    
    let db = client.db("abraruninvites").await.map_err(|_| Status::InternalServerError)?;
    let mut query = FindQuery::find_all();
    query.selector = json!({"creator_id": user.user_id});

    let run_invite_docs: DocumentCollection<ServerRunInvite> = db.find(&query).await.map_err(|_| Status::InternalServerError)?;

    for run_invite in run_invite_docs.rows {
        db.remove(&run_invite).await;
    }

    let db = client.db("abragroups").await.map_err(|_| Status::InternalServerError)?;
    let mut query = FindQuery::find_all();
    query.selector = json!({"users": {"$elemMatch": {"$eq": user.user_id}}});

    let group_docs: DocumentCollection<ServerGroup> = db.find(&query).await.map_err(|_| Status::InternalServerError)?;

    for group in group_docs.rows {
        let mut group = group.clone();
        group.users.retain(|&x| x != user.user_id);
        let _ = db.save(&mut group).await;
    }

    let db = client.db("abragroups").await.map_err(|_| Status::InternalServerError)?;
    let mut query = FindQuery::find_all();
    query.selector = json!({"owner": user.user_id});

    let group_docs: DocumentCollection<ServerGroup> = db.find(&query).await.map_err(|_| Status::InternalServerError)?;

    for group in group_docs.rows {
        db.remove(&group).await;
    }

    let db = client.db("abragrouprequests").await.map_err(|_| Status::InternalServerError)?;
    let mut query = FindQuery::find_all();
    query.selector = json!({"owner_name": user.name});

    let request_docs: DocumentCollection<ServerGroupRequest> = db.find(&query).await.map_err(|_| Status::InternalServerError)?;

    for request in request_docs.rows {
        db.remove(&request).await;
    }

    let db = client.db("abragrouprequests").await.map_err(|_| Status::InternalServerError)?;
    let mut query = FindQuery::find_all();
    query.selector = json!({"invited_user": user.user_id});

    let request_docs: DocumentCollection<ServerGroupRequest> = db.find(&query).await.map_err(|_| Status::InternalServerError)?;

    for request in request_docs.rows {
        db.remove(&request).await;
    }

    Result::Ok(Status::Ok)

}

async fn delete_run(user: User, run_start: i64) -> Result<Status, Status>{
    //Connect and open the db
    let client = Client::new("http://localhost:5984", &env::var("database_username").unwrap(), &env::var("database_password").unwrap()).map_err(|_| Status::InternalServerError)?;
    let db = client.db("abraruns").await.map_err(|_| Status::InternalServerError)?;

    //Run a mango query for the user id and run start time
    let mut query = FindQuery::find_all();
    query.selector = json!({"user_id": user.user_id, "start_time": run_start});
    let run_docs: DocumentCollection<ServerRun> = db.find(&query).await.map_err(|_| Status::InternalServerError)?;

    if run_docs.total_rows < 1{
        return Result::Ok(Status::Ok);
    }

    let result = db.remove(&run_docs.rows[0]).await;
    
    if !result {
        return Result::Err(Status::InternalServerError)
    }

    Result::Ok(Status::Ok)
}

async fn sign_out_user(user: User) -> Result<(), Status>{
    //Connect and open the db
    let Result::Ok(client) = Client::new("http://localhost:5984", &env::var("database_username").unwrap(), &env::var("database_password").unwrap()) else {return Err(Status::InternalServerError)};
    let Result::Ok(db) = client.db("abrausers").await.map_err(|_| Status::InternalServerError) else {return Err(Status::InternalServerError)};

    let mut user = user.clone();
    user.token_expiry = 0;

    db.save(&mut user).await.map_err(|_| Status::InternalServerError)?;


    Ok(())
}

async fn leave_group(user: User, group_id: GroupID) -> Result<Status, Status>{
    let client = Client::new("http://localhost:5984", &env::var("database_username").unwrap(), &env::var("database_password").unwrap()).map_err(|_| Status::InternalServerError)?;
    let db = client.db("abragroups").await.map_err(|_| Status::InternalServerError)?;
    let mut query = FindQuery::find_all();
    query.selector = json!({"group_id": group_id.group_id});

    let group_docs: DocumentCollection<ServerGroup> = db.find(&query).await.map_err(|_| Status::InternalServerError)?;

    if group_docs.total_rows != 1{
        return Result::Err(Status::InternalServerError);
    }

    if user.user_id == group_docs.rows[0].owner {
        let result = db.remove(&group_docs[0]).await;
        if !result {
            return Err(Status::InternalServerError)
        }
        return Result::Ok(Status::Ok);
    }

    if group_docs.rows[0].users.contains(&user.user_id){
        let mut group = group_docs[0].clone();
        group.users.retain(|&x| x != user.user_id);
        db.save(&mut group).await.map_err(|_| Status::InternalServerError)?;
        return Result::Ok(Status::Ok);
    }

    Result::Ok(Status::Unauthorized)
}

async fn post_run(user: User, post: Post) -> Result<Status, Status> {
    let client = Client::new("http://localhost:5984", &env::var("database_username").unwrap(), &env::var("database_password").unwrap()).map_err(|_| Status::InternalServerError)?;
    let db = client.db("abraposts").await.map_err(|_| Status::InternalServerError)?;

    let mut server_post = ServerPost {
        _id: String::new(),
        _rev: String::new(),
        uuid: Uuid::new_v4().to_string(),
        run: post.run,
        comment: post.comment,
        username: user.name,
    };

    if let Ok(_) = db.create(&mut server_post).await{
        return Result::Ok(Status::Ok);
    }else{
        return Result::Err(Status::InternalServerError);
    }
}

async fn get_posted_runs(user: User, latlong: LatLon){

}

#[get("/")]
fn index() -> &'static str{
    "Hello, World"
}

#[post("/user", format = "application/json", data = "<user>")]
async fn new_user(user: Json<SignUpUser>) -> Result<String, Status> {
    store_user(user.into_inner()).await
}

#[post("/sign_in", format = "application/json", data = "<user>")]
async fn sign_in(user: Json<SignUpUser>) -> Result<String, Status>{
    check_user(user.into_inner()).await
}
#[post("/new_run", format = "application/json", data = "<run>")]
async fn new_run(run: Json<Run>, auth_header: AuthorizationHeader) -> Result<String, Status>{
    //Get the session token
    if let Ok(full_session_token) = parse_bearer_token(&auth_header.0){
        let session_token = split_u128_to_u32(full_session_token.0);
        let user_id = full_session_token.1;
        let user = authorize_user(&session_token, user_id).await?;
        return store_run(run.into_inner(), user).await;
    }else{
        return Result::Err(Status::BadRequest);
    }
}

#[get("/get_runs", format = "application/json")]
async fn get_runs(auth_header: AuthorizationHeader) -> Result<Json<Vec<ReturnRun>>, Status>{
    //Get the session token
    if let Ok(full_session_token) = parse_bearer_token(&auth_header.0){
        let session_token = split_u128_to_u32(full_session_token.0);
        let user_id = full_session_token.1;
        let user = authorize_user(&session_token, user_id).await?;
        return get_runs_from_server(user).await;
    }else{
        return Result::Err(Status::BadRequest);
    }
}
#[post("/new_group", format = "application/json", data = "<group_data>")]
async fn new_group(auth_header: AuthorizationHeader, group_data: Json<CreationGroup>) -> Result<Status, Status>{
    if let Ok(full_session_token) = parse_bearer_token(&auth_header.0){
        let session_token = split_u128_to_u32(full_session_token.0);
        let user_id = full_session_token.1;
        let user = authorize_user(&session_token, user_id).await?;
        return create_group_on_server(user, group_data.into_inner()).await;
    }else{
        return Result::Err(Status::BadRequest);
    }
}
#[post("/group_add_request", format = "application/json", data = "<group_data>")]
async fn group_add_request(auth_header: AuthorizationHeader, group_data: Json<AddGroupRequest>) -> Result<Status, Status>{
    if let Ok(full_session_token) = parse_bearer_token(&auth_header.0){
        let session_token = split_u128_to_u32(full_session_token.0);
        let user_id = full_session_token.1;
        let user = authorize_user(&session_token, user_id).await?;
        return invite_user(user, group_data.into_inner()).await;
    }else{
        return Result::Err(Status::BadRequest);
    }
}
#[get("/fetch_group_requests", format = "application/json")]
async fn fetch_group_requests(auth_header: AuthorizationHeader) -> Result<Json<Vec<GroupRequest>>, Status>{
    if let Ok(full_session_token) = parse_bearer_token(&auth_header.0){
        let session_token = split_u128_to_u32(full_session_token.0);
        let user_id = full_session_token.1;
        let user = authorize_user(&session_token, user_id).await?;
        return get_group_requests(user).await;
    }else{
        return Result::Err(Status::BadRequest);
    }
}


#[post("/respond_group_request", format = "application/json", data = "<group_data>")]
async fn respond_group_request(auth_header: AuthorizationHeader, group_data: Json<GroupRequestResponse>) -> Result<Status, Status>{
    if let Ok(full_session_token) = parse_bearer_token(&auth_header.0){
        let session_token = split_u128_to_u32(full_session_token.0);
        let user_id = full_session_token.1;
        let user = authorize_user(&session_token, user_id).await?;
        return group_request_response(user, group_data.into_inner()).await;
    }else{
        return Result::Err(Status::BadRequest);
    }
}

#[get("/get_groups", format = "application/json")]
async fn get_groups(auth_header: AuthorizationHeader) -> Result<Json<Vec<GetGroupResponse>>, Status>{
    if let Ok(full_session_token) = parse_bearer_token(&auth_header.0){
        let session_token = split_u128_to_u32(full_session_token.0);
        let user_id = full_session_token.1;
        let user = authorize_user(&session_token, user_id).await?;
        return get_my_groups(user).await;
    }else{
        return Result::Err(Status::BadRequest);
    }
}

#[post("/get_group_runs", format = "application/json", data = "<group_data>")]
async fn get_group_run(auth_header: AuthorizationHeader, group_data: Json<GroupID>) -> Result<Json<Vec<GroupRun>>, Status>{
    if let Ok(full_session_token) = parse_bearer_token(&auth_header.0){
        let session_token = split_u128_to_u32(full_session_token.0);
        let user_id = full_session_token.1;
        let user = authorize_user(&session_token, user_id).await?;
        return get_group_runs(user, group_data.into_inner().group_id).await;
    }else{
        return Result::Err(Status::BadRequest);
    }
}
#[post("/create_run_invite", format = "application/json", data = "<invite>")]
async fn create_run_invite(auth_header: AuthorizationHeader, invite: Json<RunInvite>) -> Result<Status, Status>{
    if let Ok(full_session_token) = parse_bearer_token(&auth_header.0){
        let session_token = split_u128_to_u32(full_session_token.0);
        let user_id = full_session_token.1;
        let user = authorize_user(&session_token, user_id).await?;
        return new_run_invite(user, invite.into_inner()).await;
    }else{
        return Result::Err(Status::BadRequest);
    }
}
#[post("/get_run_invites", format = "application/json", data = "<group_data>")]
async fn fetch_run_invites(auth_header: AuthorizationHeader, group_data: Json<GroupID>) -> Result<Json<Vec<ReturnRunInvite>>, Status>{
    if let Ok(full_session_token) = parse_bearer_token(&auth_header.0){
        let session_token = split_u128_to_u32(full_session_token.0);
        let user_id = full_session_token.1;
        let user = authorize_user(&session_token, user_id).await?;
        return get_run_invites(user, group_data.into_inner()).await;
    }else{
        return Result::Err(Status::BadRequest);
    }
}
#[get("/delete_account", format = "application/json")]
async fn delete_acc(auth_header: AuthorizationHeader) -> Result<Status, Status>{
    if let Ok(full_session_token) = parse_bearer_token(&auth_header.0){
        let session_token = split_u128_to_u32(full_session_token.0);
        let user_id = full_session_token.1;
        let user = authorize_user(&session_token, user_id).await?;
        return delete_account(user).await;
    }else{
        return Result::Err(Status::BadRequest);
    }
}

#[get("/sign_out", format = "application/json")]
async fn sign_out(auth_header: AuthorizationHeader) -> Result<Status, Status>{
    if let Ok(full_session_token) = parse_bearer_token(&auth_header.0){
        let session_token = split_u128_to_u32(full_session_token.0);
        let user_id = full_session_token.1;
        let user = authorize_user(&session_token, user_id).await?;
        sign_out_user(user).await?;
        return Result::Ok(Status::Ok);
    }else{
        return Result::Err(Status::BadRequest);
    }
}

#[post("/delete_run", format = "application/json", data = "<run_id>")]
async fn delete_run_helper(auth_header: AuthorizationHeader, run_id: Json<RunID>) -> Result<Status, Status>{
    if let Ok(full_session_token) = parse_bearer_token(&auth_header.0){
        let session_token = split_u128_to_u32(full_session_token.0);
        let user_id = full_session_token.1;
        let user = authorize_user(&session_token, user_id).await?;
        return delete_run(user, run_id.into_inner().start_time).await;
    }else{
        return Result::Err(Status::BadRequest);
    }
}

#[post("/leave_group", format = "application/json", data = "<group_data>")]
async fn leave_group_helper(auth_header: AuthorizationHeader, group_data: Json<GroupID>) -> Result<Status, Status> {
    if let Ok(full_session_token) = parse_bearer_token(&auth_header.0){
        let session_token = split_u128_to_u32(full_session_token.0);
        let user_id = full_session_token.1;
        let user = authorize_user(&session_token, user_id).await?;
        return leave_group(user, group_data.into_inner()).await;
    }else{
        return Result::Err(Status::BadRequest);
    }
}

#[post("/post_run", format = "application/json", data = "<post_data>")]
async fn post_run_helper(auth_header: AuthorizationHeader, post_data: Json<Post>) -> Result<Status, Status> {
    if let Ok(full_session_token) = parse_bearer_token(&auth_header.0){
        let session_token = split_u128_to_u32(full_session_token.0);
        let user_id = full_session_token.1;
        let user = authorize_user(&session_token, user_id).await?;
        return post_run(user, post_data.into_inner()).await;
    }else{
        return Result::Err(Status::BadRequest);
    }
}

#[launch]
fn rocket() -> _ {
    //Ensure that env variables are accessible
    let _ = env::var("database_username").unwrap();
    let _ = env::var("database_password").unwrap();
    rocket::build()
    .mount("/", routes![index, new_user, sign_in, new_run, get_runs, new_group, group_add_request, fetch_group_requests, respond_group_request, get_groups, get_group_run, create_run_invite, fetch_run_invites, delete_acc, sign_out, delete_run_helper, leave_group_helper, post_run_helper])
}
