//
//  ViewController.swift
//  AwsMobile
//
//  Created by Juan Navarro  on 5/7/21.
//

// Aplicacion de autenticacion y almacenamiento en servicio en la nube de AWS
// App that allows the user to create notes
// aws.amazon.com/mobilehub


// APIs and building blocks for developers who want to create user authentication experiences

import UIKit
import AWSAuthCore
import AWSAuthUI
import AWSCore
import AWSDynamoDB
import AWSS3

// ------------- GOOGLE SIG-IN -------------
// Web client
// 1023536450180-ssvcnl74p6hegs1pbps1f4ptjdrpcg08.apps.googleusercontent.com
// secret: QsO3XPioEircfk3ynkgD0Gbn

// iOS:
//1023536450180-7tm4i3h8hmmmpm6tnpe8na82nm4fbumv.apps.googleusercontent.com
// -----------------------------------------

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func doBtnLogout(_ sender: Any) {
        // Check if user is logged in to log out, and then check for login again for other user
        AWSSignInManager.sharedInstance().logout { (value, error) in
            self.checkForLogin()
        }
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        checkForLogin()
    }
    
    func uploadFile() {
        var completionHandler : AWSS3TransferUtilityUploadCompletionHandlerBlock?
        completionHandler = { (task,error) in
            // If we're updating the UI, we would need to do taht in the main thread. We're just going to print out the response
            print (task.response?.statusCode ?? "0")
            print (error?.localizedDescription ?? "no error")
        }
        
        // Upload progress monitoring
        let exp = AWSS3TransferUtilityUploadExpression()
        exp.progressBlock = {(task,progress) in
            DispatchQueue.main.async {
                // update UI
                print(progress.fractionCompleted) // The fractionCompleted will be a decimal number between zero and one, one means completed
            }
        }
        // El archivo que  vamos a subir
        let data = UIImageJPEGRepresentation(#imageLiteral(resourceName: "beach.jpeg"), 0.5)
        
        let tUtil = AWSS3TransferUtility.default()
        // The key is the location of the file
        tUtil.uploadData(data!, key: "public/pic.jpg", contentType: "image/jpg", expression: exp, completionHandler: completionHandler)
    }
    
    func downloadData() {
        // We can download files to a URL, which means it'll save it to the file system and pass in a URL that we can read it from, or,
        // we can download directly to a data instance in memory
        var completionHandler : AWSS3TransferUtilityDownloadCompletionHandlerBlock?
        // The completion handler takes both, the URL and the data object, if you're downloading it to a URL, then the data object will be nil, and viceversa
        completionHandler = { (task, URL, data, error) in
            DispatchQueue.main.async {
                let iv = UIImageView.init(frame: self.view.bounds)
                iv.contentMode = .scaleAspectFit
                iv.image = UIImage.init(data: data!)
                self.view.addSubview(iv)
            }
        }
        
        let tUtil = AWSS3TransferUtility.default()
        tUtil.downloadData(forKey: "public/pic.jpg", expression: nil, completionHandler: completionHandler)
        
    }
    
    func deleteFile() {
        let s3 = AWSS3.default()
        let dor = AWSS3DeleteObjectRequest()
        // Delete Object Request
        dor?.bucket = "notes-userfiles-mobilehub-1331095315"
        dor?.key = "public/pic.jpg"
        s3.deleteObject(dor!) { (output, error) in
            print (output)
            print (error)
        }
    }
    
    func checkForLogin() {
        // Check if any user already logged in, and not present the user interface if they alredy are.
        // the user interface is provided by the library AWSAuthUI
        // Cuando se inicia sesion por 1 vez, ese logeo se queda registrado automaticamente para que el usaurio no tenga que de nuevo estar poniendo las credenciales, a menos que cierre session
        if !AWSSignInManager.sharedInstance().isLoggedIn { // If not logged in
            // We use default configuration (.:nil), configurations allows for changing of colors, image, etc, in the AWSAuthUI
            AWSAuthUIViewController.presentViewController(with: self.navigationController!, configuration: nil) { (provider, error) in
                if error == nil {
                    print ("success")
                }
                else {
                    print (error?.localizedDescription ?? "no value")
                }
            }
        }
        else {
//            createNote(noteID: "100")
//            createNote(noteID: "101")
//            createNote(noteID: "102")
//            loadNote(noteID: "123")
//            updateNote(noteID: "123", content: "Updated note")
//            deleteNote(noteID: "123")
//            queryNotes()
//            uploadFile()
//            downloadData()
            deleteFile()
        }
    }
    
    func createNote(noteID : String) {
        guard let note = Note() else { return } // Make sure that I actually get a note creted. (We don't wanna keep going if we weren't able to create an instnace of Note)
        // Now I have an instance of note, we wanna populate it
        note._userId = AWSIdentityManager.default().identityId // Returns the identity Manager singleton instance configured using the information provided in 'awsconfiguration.json' or 'info.plist' file
        note._noteId = noteID
        note._content = "Text for my note"
        note._creationDate = Date().timeIntervalSince1970 as NSNumber
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        note._title = "My note on \(df.string(from: Date()))"
        saveNote(note : note)
    }
    
    func saveNote(note : Note) {
        // AWSDynamoDBObjectMapper: Object mapper for domain-object interaction with DynamoDB
        // .default: Returns the singleton service client
        let dbObjMapper = AWSDynamoDBObjectMapper.default()
        // Save the model object to an Amazon DynamoDB table using default configuration
        dbObjMapper.save(note) { (error) in
            print (error?.localizedDescription ?? "no error")
        }
    }
    
    func loadNote(noteID : String) {
        let dbObjMapper = AWSDynamoDBObjectMapper.default()
        if let hashKey = AWSIdentityManager.default().identityId {
            dbObjMapper.load(Note.self, hashKey: hashKey, rangeKey: noteID) { (model, error) in
                if let note = model as? Note {
                    print (note._content ?? "no content")
                }
            }
        }
    }

    func updateNote(noteID : String, content : String) {
        let dbObjMapper = AWSDynamoDBObjectMapper.default()
        if let hashKey = AWSIdentityManager.default().identityId {
            dbObjMapper.load(Note.self, hashKey: hashKey, rangeKey: noteID) { (model, error) in
                if let note = model as? Note {
                    note._content = content
                    self.saveNote(note: note)
                }
            }
        }
    }
    
    func deleteNote(noteID : String) {
        if let note = Note() {
            note._userId = AWSIdentityManager.default().identityId
            note._noteId = noteID
            let dbObjMapper = AWSDynamoDBObjectMapper.default()
            dbObjMapper.remove(note) { (error) in
                print (error?.localizedDescription ?? "no error")
            }
        }
    }
    
    func queryNotes() {
        let qExp = AWSDynamoDBQueryExpression()
        // Setting the conditions, attributes, and values to match
        qExp.keyConditionExpression = "#uId = :userId and #noteId > :someId"
        
        qExp.expressionAttributeNames = ["#uId":"userId", "#noteId":"noteId"]
        qExp.expressionAttributeValues = [":userId":AWSIdentityManager.default().identityId!, ":someId":"100"]
        
        let objMapper = AWSDynamoDBObjectMapper.default()
        objMapper.query(Note.self, expression: qExp) { (output, error) in
            if let notes = output?.items as? [Note] {
                notes.forEach({ (note) in
                    print (note._content ?? "no content")
                    print (note._noteId ?? "no id")
                })
            }
        }
    }
}

