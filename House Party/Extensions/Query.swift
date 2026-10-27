//
//  QueryExtensions.swift
//  Meetup
//
//  Created by Marcel Schafaczek on 20.05.25.
//

import FirebaseFirestore
import Combine

extension Query {
    
    public func getDocuments<T>(as type: T.Type) async throws -> [T] where T: Decodable {
        return try await self.getDocumentsWithSnapshot(as: type).result
    }
    
    public func getDocumentsWithSnapshot<T>(as type: T.Type) async throws -> (result: [T], lastDocument: DocumentSnapshot?) where T: Decodable {
        let snapshot = try await self.getDocuments()
        
        let products = try snapshot.documents.map({ document in
            return try document.data(as: T.self)
        })
        
        return (products, snapshot.documents.last)
    }
    
    public func startOptionally(afterDocument lastDocument: DocumentSnapshot?) -> Query {
        guard let lastDocument = lastDocument else {
            return self
        }
                
        return self.start(afterDocument: lastDocument)
    }
    
    public func aggregateCount() async throws -> Int {
        let snapshot = try await self.count.getAggregation(source: .server)
        return Int(truncating: snapshot.count)
    }
    
    public func addSnapshotListener<T>(as type: T.Type) -> (publisher: AnyPublisher<[T], Error>, listener: ListenerRegistration) where T: Decodable {
        let publisher = PassthroughSubject<[T], Error>()
        
        let listener = self.addSnapshotListener { querySnapshot, error in
            if let error {
                publisher.send(completion: .failure(error))
                return
            }
            
            guard let documents = querySnapshot?.documents else {
                publisher.send([])
                return
            }
            
            do {
                let mappedDocuments: [T] = try documents.map { try $0.data(as: T.self) }
                publisher.send(mappedDocuments)
            }
            catch {
                publisher.send(completion: .failure(error))
            }
        }
        
        return (publisher.eraseToAnyPublisher(), listener)
    }
}
