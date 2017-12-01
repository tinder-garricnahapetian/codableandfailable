
// Swift 4

import Foundation

// Swift 4's Codable is awesome. It allows us to easily encode and decode our Swift entities to and from Data.
// We started exploring how we could use Codable as soon as our project was converted to Swift 4.
// We gained the following insight through this process:
// 1. The entire Decoding process will fail in certain cases if decoding fails for just one property of the Decodable type
// // even if that property is optional
// 2. This failure can be prevented with some extra work.
// 3. Successful conformance of Arbitary JSON data to Codable works with some extra effort
// Let's look at each insight in turn starting with #1. For the purposes of our discussion
// we will use the following Codable entity:

struct Person: Codable {
    let name: String
    let age: Int
}

// INSIGHT #1

/*
The entire Decoding process will fail in certain cases if decoding fails for just one property of the Decodable type,
even if that property is optional.
*/

// NORMAL ENCODING AND DECODING

// First, let's take a look at how a normal encoding and decoding works:

let garric = Person(name: "garric", age: 33) // Create a Person
let encodedGarric = try JSONEncoder().encode(garric) // Encode it to Data
let decodedGarric = try JSONDecoder().decode(Person.self, from: encodedGarric) // Decode it back to Person

// As you can see, Codable makes it super easy to encode Swift entities to Data and decode them back to their type.

// We can even create a JSON represenation of our entity from the encoded data:
let jsonGarric = try JSONSerialization.jsonObject(with: encodedGarric, options: .allowFragments) as! [String: Any]

// Or a json string representation:
let stringJSONGarric = String(data: encodedGarric, encoding: .utf8)!

// We can even convert our stringJSONGarric back into data:
let stringJSONDataGarric = stringJSONGarric.data(using: .utf8)!

// And then decode that back into Person.self
try JSONDecoder().decode(Person.self, from: stringJSONDataGarric)

// WHEN THINGS GO WRONG

// Let's say we have a valid json string like so:

let validPersonJSONData: Data = """
{
    "name": "garric",
    "age": 33
}
""".data(using: .utf8)!

// Everything works fine when we try to encode and decode Person.self from validPersonJSON:

try! JSONDecoder().decode(Person.self, from: validPersonJSONData)

// MISSING KEY

// But what about when an expected key is missing from our JSON?
// In the following example, the key `age` is missing:

let missingKeyJSONData: Data = """
{
"name": "garric"
}
""".data(using: .utf8)!

// If we force try (try!) using `missingKeyJSONData`, we get the following error:

//let person = try! JSONDecoder().decode(Person.self, from: missingKeyJSONData)

/*

 fill in error

*/

// This is a Swift Decoding Error and it gives us quite a lot of information.
// Swift.DecodingError is an enum and the case we got is .keyNotFound
// That case takes a key which is Person.CodingKeys.age,
// and it takes a Swift.DecodingError.Context
// which takes a coding path which is Person.CodingKeys.age,
// and a description which is the String: "No value associated with key last (\"age\")."
// Notice that the entire decoding process failed just because of this one error.
// We force try in this example just so we can see the error. If we dont force try, the error is appears to be caught somewhere...?
// In an ideal world, this key would never be missing but things happen sometimes in production, right?

// SOLUTION

// NOTE: - Be sure to comment out line 81 (try!) or change `try!` to `try?` prior to running line 117.
// So, assuming last name is not required from a business standpoint,
// we can solve this potential issue by making age optional:

struct OptionalAgePerson: Codable {
    let name: String
    let age: Int?
}

try! JSONDecoder().decode(OptionalAgePerson.self, from: missingKeyJSONData)

// During the decoding process, when the decoder sees that the key `age` is not present,
// it appears to check if the property for that CodingKey is optional, and if it is,
// it sets the value of that property to nil. Pretty cool, right?

// NULL VALUE FOR OPTIONAL PROPERTY

// Codable even handles the value `null` very well:

let nullValueJSONData: Data = """
{
"name": "garric"
"age": null
}
""".data(using: .utf8)!

//let nullValuePerson = try! JSONDecoder().decode(OptionalLastNamePerson.self, from: nullValueJSONData)

// It appears that Decoder handles the null value case the same way as a missing key for a property that is optional.
// Great, right?

// NULL VALUE FOR NON-OPTIONAL PROPERTY

// Decoder handles a null value for a non-optional property in a similar way in that the decoding process fails,
// which makes sense, but the error is different which is cool:

/*

 fill in error

*/

// UNSUPPORTED KEY

// Let's say you ship your version 1.0 of your app using Codable and everything is going great,
// then you update your API by adding a new key and value and you ship version 1.1
// but you dont have API versioning in place. How does Codable handle this for users that are still on version 1.0?

let unsupportedKeyJSONData: Data = """
{
"name": "Garric",
"unsupported": "unsupported",
"age": 33
}
""".data(using: .utf8)!

try! JSONDecoder().decode(Person.self, from: unsupportedKeyJSONData)

// Codable handles this issue very well. As you can see, even though our JSON Data contains an unsupported key,
// the decoding process continues and we are left with a fully decoded Person.

// TYPE MISMATCH

// What happens if your server accidentally sends down the wrong data type? How does Decoder handle this?
// In the following example, the JSON contains an String instead of an Int for key `age`:

let typeMismatchJSONData: Data = """
{
"name": "garric",
"age": "33"
}
""".data(using: .utf8)!

//try! JSONDecoder().decode(Person.self, from: typeMismatchJSONData)

// This produces a type mismatch error and the entire decoding process fails:

/*
 Fatal error: 'try!' expression unexpectedly raised an error:
 Swift.DecodingError.typeMismatch(Swift.Int,
 Swift.DecodingError.Context(codingPath: [__lldb_expr_1.Person.(CodingKeys in _0270D682B860B53A3A7C2CB46A41ADC8).age],
 debugDescription: "Expected to decode Int but found a string/data instead.", underlyingError: nil)): file
 /BuildRoot/Library/Caches/com.apple.xbs/Sources/swiftlang/swiftlang-900.0.69.2/src/swift/stdlib/public/core/ErrorType.swift,
 line 181
*/

// It makes sense that the decoding process should fail given a type mismatch,
// but what if we want the decoding process to continue? How could we solve this?
// Making the property optional doesnt help:

//try! JSONDecoder().decode(OptionalAgePerson.self, from: typeMismatchJSONData)

// You see? We get the same error as before.

// So, how can we solve this? Found out about one possible solution in the next article.

// INSIGHT #2: PARTIALLY FAILABLE DECODING PROCESS

// One possible solution to the problem of the decoding process failing when just one property fails to decode,
// is to wrapp our failable properties in an Either type; let's call it Failable:

enum Failable<Value: Decodable>: Decodable {
    case value(Value)
    case error(Error)
    public init(from decoder: Decoder) throws {
        do {
            self = .value(try decoder.singleValueContainer().decode(Value.self))
        } catch {
            self = .error(error)
        }
    }
}

// We use it like this:

struct PersonWithFailableProperty: Decodable {
    let name: String
    let age: Failable<Int>
}

// Let's see what happens now:

try! JSONDecoder().decode(PersonWithFailableProperty.self, from: typeMismatchJSONData)

// We dont crash. Yay! The person has a name and their age is Failable.error(.typeMismatch). Pretty cool, right?


