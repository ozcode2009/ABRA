//
//  SignInView.swift
//  ABRA
//
//  Created by Oliver Crumrine on 7/1/24.
//

import SwiftUI
import MapKit

struct SignInView: View {
    @State private var email            = "";
    @State private var password         = "";
    @State private var username         = "";
    @State private var state            = 0;
    @State private var showErrorText    = false;
    @State private var workingOnIt      = false;
    @State private var signInAccount    = false;
    @State private var showingToS       = false;
    @State private var showingPrivacy   = false;
    @State private var errorText        = "";
    @State private var region           = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    );
    
    var body: some View {
        ZStack {
            Map(coordinateRegion: $region)
                .edgesIgnoringSafeArea(.all)
                .blur(radius: 5)
            VStack{
                if(!signInAccount) {
                    if(state == 0){
                        VStack{
                            Text("Welcome to ABRA")
                                .font(.largeTitle)
                                .bold()
                                .padding(.top)
                                .foregroundColor(Color.primary.opacity(0.4))
                            
                            Text("Create a new account")
                                .font(.callout)
                            
                            Text(errorText)
                                .font(.callout)
                                .foregroundStyle(.red)
                            VStack {
                                
                                TextField("Enter email", text: $email)
                                    .keyboardType(.emailAddress)
                                    .textContentType(.emailAddress)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .padding()
                                    .frame(height: 40)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(14)
                                    .shadow(radius: 2)
                                
                                
                                SecureField("Enter password", text: $password)
                                    .padding()
                                    .frame(height: 40)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(14)
                                    .shadow(radius: 2)
                            }
                            .padding()
                            
                            Text("By signing up you accept the")
                                .font(.footnote)
                            HStack {
                                Button("Terms of Service"){
                                    showingToS = true;
                                }.foregroundColor(.blue).font(.footnote)
                                Text("and").font(.footnote)
                                Button("Privacy Policy"){
                                    showingPrivacy = true;
                                }.foregroundColor(.blue).font(.footnote)
                            }
                            
                            Text("Already have an account? Click to sign in.")
                                .onTapGesture {
                                    signInAccount = true;
                                }
                                .foregroundStyle(.blue).padding(.top, 3)
                            
                            Button {
                                if(validateEmailAndPassword()){
                                    state = 1;
                                }
                            } label: {
                                ZStack {
                                    Text("Continue")
                                        .bold()
                                        .foregroundStyle(Color.primary)
                                        .frame(maxWidth: .infinity, maxHeight: 50)
                                        .background(.blue)
                                        .cornerRadius(14)
                                        .padding()
                                }
                            }
                            
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .foregroundStyle(Color.primary.opacity(0.35))
                        .foregroundStyle(.ultraThinMaterial)
                        .cornerRadius(35)
                        .padding()
                        .padding(.top)
                    }else{
                        VStack{
                            HStack{
                                Button(action: {
                                    state = 0;
                                }) {
                                    Image(systemName: "chevron.backward.circle.fill")
                                        .foregroundStyle(.gray)
                                        .font(.title)
                                }
                                Text("Welcome to ABRA")
                                    .font(.largeTitle)
                                    .bold()
                                    .foregroundColor(Color.primary.opacity(0.4))
                                
                            }.padding(.top)
                            
                            Text("Almost done")
                                .font(.callout)
                            
                            Text(errorText)
                                .font(.callout)
                                .foregroundStyle(.red)
                            
                            VStack {
                                
                                TextField("Enter a username", text: $username)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .padding()
                                    .frame(height: 50)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(14)
                                    .shadow(radius: 2)
                            }
                            .padding()
                            
                            Text("Make sure to set your settings once you've signed up")
                                .font(.footnote)
                            
                            if(workingOnIt){
                                ProgressView().padding(.top)
                            }
                            
                            Button {
                                workingOnIt = true;
                                Task{
                                    setupUnits()
                                    RunCoordinator.shared.getLocationStatus(request: true)
                                    let result = await signUp(email: email, password: password, username: username);
                                    if result == .emailTaken {
                                        workingOnIt = false;
                                        state = 0;
                                        errorText = "Email already taken"
                                        showErrorText = true;
                                    }
                                    if result == .usernameTaken {
                                        errorText = "Username already taken"
                                        showErrorText = true;
                                        workingOnIt = false;
                                    }
                                    if result == .ISE {
                                        errorText = "Error signing you up"
                                        showErrorText = true;
                                        workingOnIt = false;
                                    }
                                }
                            } label: {
                                ZStack {
                                    Text("Sign Up")
                                        .bold()
                                        .foregroundStyle(Color.primary)
                                        .frame(maxWidth: .infinity, maxHeight: 50)
                                        .background(.blue)
                                        .cornerRadius(14)
                                        .padding()
                                }
                            }
                            
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .foregroundStyle(Color.primary.opacity(0.35))
                        .foregroundStyle(.ultraThinMaterial)
                        .cornerRadius(35)
                        .padding()
                        .padding(.top)
                        .padding(.top)
                    }
                }else{
                    VStack{
                        Text("Welcome Back")
                            .font(.largeTitle)
                            .bold()
                            .padding(.top)
                            .foregroundColor(Color.primary.opacity(0.4))
                        
                        Text("Sign in")
                            .font(.callout)
                        
                        Text(errorText)
                            .font(.callout)
                            .foregroundStyle(.red)
                        VStack {
                            
                            TextField("Enter email", text: $email)
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .padding()
                                .frame(height: 40)
                                .background(.ultraThinMaterial)
                                .cornerRadius(14)
                                .shadow(radius: 2)
                            
                            
                            SecureField("Enter password", text: $password)
                                .padding()
                                .frame(height: 40)
                                .background(.ultraThinMaterial)
                                .cornerRadius(14)
                                .shadow(radius: 2)
                        }
                        .padding()
                        
                        if(workingOnIt){
                            ProgressView().padding(.top)
                        }
                        
                        Button {
                            workingOnIt = true;
                            Task{
                                let result = await signIn(email: email, password: password);
                                if result == .unauthorized {
                                    errorText = "Email or password incorrect"
                                    showErrorText = true;
                                    workingOnIt = false;
                                }
                                if result == .ISE {
                                    errorText = "Error signing in"
                                    showErrorText = true;
                                    workingOnIt = false;
                                }
                            }
                        } label: {
                            ZStack {
                                Text("Sign In")
                                    .bold()
                                    .foregroundStyle(Color.primary)
                                    .frame(maxWidth: .infinity, maxHeight: 50)
                                    .background(.blue)
                                    .cornerRadius(14)
                                    .padding()
                            }
                        }
                        
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .foregroundStyle(Color.primary.opacity(0.35))
                    .foregroundStyle(.ultraThinMaterial)
                    .cornerRadius(35)
                    .padding()
                    .padding(.top)
                }
                Spacer()
            }
        }.sheet(isPresented: $showingToS){
            TermsOfServiceView()
        }.sheet(isPresented: $showingPrivacy){
            PrivacyPolicyView()
        }
        
    }
    func validateEmail() -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        
        if email.isEmpty {
            errorText = "Email cannot be empty."
            showErrorText = true
            return false
        } else if !emailPredicate.evaluate(with: email) {
            errorText = "Please enter a valid email address."
            showErrorText = true
            return false
        } else {
            showErrorText = false
            return true
        }
    }

    func validatePassword() -> Bool {
        if password.isEmpty {
            errorText = "Password cannot be empty."
            showErrorText = true
            return false
        } else if password.count < 8 {
            errorText = "Password must be at least 8 characters long."
            showErrorText = true
            return false
        } else {
            showErrorText = false
            return true
        }
    }

    func validateEmailAndPassword() -> Bool {
        let isPasswordValid = validatePassword()
        let isEmailValid = validateEmail()
        return isEmailValid && isPasswordValid
    }
    func setupUnits(){
        let usesMetric = Locale.current.measurementSystem == .metric
        
        if(usesMetric) {
            UserDefaults.standard.setValue(0, forKey: "temperatureUnit")
            UserDefaults.standard.setValue(0, forKey: "distanceUnit")
            UserDefaults.standard.setValue(0, forKey: "isKg")
            UserDefaults.standard.setValue(62.0, forKey: "weight")
        }else{
            UserDefaults.standard.setValue(1, forKey: "temperatureUnit")
            UserDefaults.standard.setValue(1, forKey: "distanceUnit")
            UserDefaults.standard.setValue(1, forKey: "weightUnit")
            UserDefaults.standard.setValue(180.0, forKey: "weight")
        }
    }
}

struct PrivacyPolicyView: View {
    let privacyPolicy = """
    Privacy Policy for ABRA
    Last updated: 7/15/23
    Introduction
    Welcome to ABRA. We are committed to protecting your personal information and your right to privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application. This policy applies to users within the United States only, as our app is not distributed outside of the US.
    Information We Collect
    Personal Information
    We collect the following personal information:

    Email address
    Password
    Username
    Running data (location, distance, pace, time, and other related metrics)

    Usage Data
    We may also collect information that your device sends whenever you use our app, including:

    Device type
    Operating system
    App version
    Time and date of use
    IP address

    How We Use Your Information
    We use the collected information for various purposes:

    To provide and maintain our service
    To notify you about changes to our service
    To allow you to participate in interactive features of our app when you choose to do so
    To provide customer support
    To gather analysis or valuable information so that we can improve our service
    To monitor the usage of our service
    To detect, prevent and address technical issues

    Data Storage and Security
    Local Storage
    On your device, we store:

    Your email address
    Your password
    Other authentication data
    Your running data

    While this data is stored locally on your device, please be aware that you are responsible for maintaining the security of your device and preventing unauthorized access.
    Server Storage
    On our servers, we store:

    Your login information and other authentication data
    Your running data

    We implement appropriate technical and organizational measures to protect your personal data against unauthorized or unlawful processing, accidental loss, destruction, or damage. This includes enforcing HTTPS (Hypertext Transfer Protocol Secure) for all data transmissions between your device and our servers, ensuring that your data is encrypted in transit.
    Data Retention and Deletion
    We retain your data on our servers for as long as your account is active. However, we provide you with the ability to delete your account and all associated data from our servers at any time. When you choose to delete your account:

    All of your personal information and running data will be permanently removed from our servers.
    This deletion is irreversible, and we will not be able to recover this information once deleted.
    Data stored locally on your device will not be automatically deleted. You may need to uninstall the app or clear app data from your device settings to remove this local data.

    Sharing Your Information
    Running Groups
    Our app features running groups. If you join a running group:

    Members of your running group will be able to see your runs, including location, distance, pace, and time.
    You may receive invitations from group members for runs at specific places and times.

    Service Providers
    We may employ third-party companies and individuals to facilitate our service, provide the service on our behalf, perform service-related services, or assist us in analyzing how our service is used. These third parties have access to your personal information only to perform these tasks on our behalf and are obligated not to disclose or use it for any other purpose.
    Your Data Protection Rights
    CCPA Privacy Rights (California Residents)
    If you are a California resident, you are granted specific rights regarding access to your personal information under the California Consumer Privacy Act (CCPA). These rights include:

    Right to Know
    Right to Delete
    Right to Opt-Out of Sale
    Right to Non-Discrimination

    To exercise these rights, please submit a verifiable consumer request to us by:

    Emailing us at: abrabetterrunning@gmail.com
    Using the account deletion feature within the app for data deletion requests

    Children's Privacy
    Our app is not intended for children under the age of 13. We do not knowingly collect personal information from children under 13. If you are a parent or guardian and you are aware that your child has provided us with personal information, please contact us at abrabetterrunning@gmail.com
    Limitation of Liability
    While we implement stringent measures to protect your personal information, no method of transmission over the Internet or method of electronic storage is 100% secure. We strive to use commercially acceptable means to protect your personal information, but we cannot guarantee its absolute security.
    In the event of a data breach, we will notify affected users in compliance with applicable laws. However, [Running App Name] and its affiliates, officers, employees, agents, partners, and licensors shall not be liable for any direct, indirect, incidental, special, consequential or exemplary damages, including but not limited to, damages for loss of profits, goodwill, use, data or other intangible losses, resulting from any security breaches or unauthorized access to your personal information that is beyond our reasonable control.
    By using our app, you acknowledge that you understand and agree to assume these risks.
    Changes to This Privacy Policy
    We may update our Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the "Last updated" date.
    Contact Us
    If you have any questions about this Privacy Policy, please contact us:

    By email: abrabetterrunning@gmail.com
    """
    var body: some View{
        ScrollView {
            Text(privacyPolicy).multilineTextAlignment(.leading).padding()
        }
    }
}
struct TermsOfServiceView: View{
    let termsOfService = """
    Terms of Service for ABRA
    Last updated: 7/15/23
    Please read these Terms of Service ("Terms", "Terms of Service") carefully before using the ABRA mobile application (the "Service") operated by the creators and copyright holders of ABRA ("us", "we", or "our").
    Your access to and use of the Service is conditioned on your acceptance of and compliance with these Terms. These Terms apply to all visitors, users, and others who access or use the Service.
    By accessing or using the Service, you agree to be bound by these Terms. If you disagree with any part of the terms, then you may not access the Service.
    Accounts
    When you create an account with us, you must provide us with accurate, complete, and up-to-date information. Failure to do so constitutes a breach of the Terms, which may result in immediate termination of your account on our Service.
    You are responsible for safeguarding the password that you use to access the Service and for any activities or actions under your password.
    You agree not to disclose your password to any third party. You must notify us immediately upon becoming aware of any breach of security or unauthorized use of your account.
    Intellectual Property
    The Service and its original content, features, and functionality are and will remain the exclusive property of the creators and copyright holders of ABRA and its licensors. The Service is protected by copyright, trademark, and other laws of both the United States and foreign countries. Our trademarks and trade dress may not be used in connection with any product or service without the prior written consent of the creators and copyright holders of ABRA.
    User Content
    Our Service allows you to post, link, store, share and otherwise make available certain information, text, graphics, or other material ("Content"). You are responsible for the Content that you post on or through the Service, including its legality, reliability, and appropriateness.
    Prohibited Uses
    You may use the Service only for lawful purposes and in accordance with these Terms. You agree not to use the Service:

    In any way that violates any applicable national or international law or regulation.
    To transmit, or procure the sending of, any advertising or promotional material, including any "junk mail", "chain letter," "spam," or any other similar solicitation.
    To impersonate or attempt to impersonate the Company, a Company employee, another user, or any other person or entity.
    In any way that infringes upon the rights of others, or in any way is illegal, threatening, fraudulent, or harmful, or in connection with any unlawful, illegal, fraudulent, or harmful purpose or activity.

    Termination
    We may terminate or suspend your account immediately, without prior notice or liability, for any reason whatsoever, including without limitation if you breach the Terms.
    Upon termination, your right to use the Service will immediately cease. If you wish to terminate your account, you may simply discontinue using the Service or use the account deletion feature provided in the app.
    Limitation of Liability
    In no event shall [Your Company Name], nor its directors, employees, partners, agents, suppliers, or affiliates, be liable for any indirect, incidental, special, consequential or punitive damages, including without limitation, loss of profits, data, use, goodwill, or other intangible losses, resulting from:

    Your access to or use of or inability to access or use the Service;
    Any conduct or content of any third party on the Service;
    Any content obtained from the Service; and
    Unauthorized access, use or alteration of your transmissions or content, whether based on warranty, contract, tort (including negligence) or any other legal theory, whether or not we have been informed of the possibility of such damage, and even if a remedy set forth herein is found to have failed of its essential purpose.

    Disclaimer
    Your use of the Service is at your sole risk. The Service is provided on an "AS IS" and "AS AVAILABLE" basis. The Service is provided without warranties of any kind, whether express or implied, including, but not limited to, implied warranties of merchantability, fitness for a particular purpose, non-infringement or course of performance.
    Governing Law
    These Terms shall be governed and construed in accordance with the laws of the United States of America, without regard to its conflict of law provisions.
    Our failure to enforce any right or provision of these Terms will not be considered a waiver of those rights. If any provision of these Terms is held to be invalid or unenforceable by a court, the remaining provisions of these Terms will remain in effect.
    Changes
    We reserve the right, at our sole discretion, to modify or replace these Terms at any time. If a revision is material, we will try to provide at least 30 days' notice prior to any new terms taking effect. What constitutes a material change will be determined at our sole discretion.
    By continuing to access or use our Service after those revisions become effective, you agree to be bound by the revised terms. If you do not agree to the new terms, please stop using the Service.
    Contact Us
    If you have any questions about these Terms, please contact us:

    By email: abrabetterrunning@gmail.com
    """
    var body: some View{
        ScrollView{
            Text(termsOfService).multilineTextAlignment(.leading).padding()
        }
    }
}
