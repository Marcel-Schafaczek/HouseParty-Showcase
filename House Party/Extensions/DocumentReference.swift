//
//  DocumentReference.swift
//  House Party
//
//  Created by Marcel Schafaczek on 14.08.26.
//

import FirebaseFirestore
import Combine

extension DocumentReference {
    public func addSnapshotListener<T>(as type: T.Type) -> (publisher: AnyPublisher<T?, Error>, listener: ListenerRegistration) where T: Decodable {
        let publisher = PassthroughSubject<T?, Error>()
        
        let listener = self.addSnapshotListener { documentSnapshot, error in
            if let error {
                publisher.send(completion: .failure(error))
                return
            }
            
            guard let documentSnapshot, documentSnapshot.exists else {
                publisher.send(nil)
                return
            }
            
            do {
                let document = try documentSnapshot.data(as: T.self)
                publisher.send(document)
            } catch {
                publisher.send(completion: .failure(error))
            }
        }
        
        return (publisher.eraseToAnyPublisher(), listener)
    }
}
