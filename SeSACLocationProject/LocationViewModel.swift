//
//  LocationViewMdoel.swift
//  SeSACLocation
//
//  Created by Lee on 9/9/25.
//

import Foundation
import CoreLocation
import RxSwift
import RxCocoa
import Alamofire

final class LocationViewModel {

    let disposeBag = DisposeBag()

    private let defaultLocation = CLLocationCoordinate2D(latitude: 37.519485, longitude: 126.890398)

    private let locationManager = CLLocationManager()

    struct Input {
        let locationButton: ControlEvent<Void>
        let refreshButton: ControlEvent<Void>
        let authorizationChanged: Observable<CLAuthorizationStatus>
    }

    struct State {
        var savedLocation: CLLocationCoordinate2D
    }

    struct Output {
        let currentLocation: PublishRelay<CLLocationCoordinate2D>
        let authorizationStatus: PublishSubject<CLAuthorizationStatus>
        let weatherData: PublishRelay<WeatherModel>
    }


    func transform(input: Input) -> Output {

        var state = State(savedLocation: defaultLocation)

        let currentLocation = PublishRelay<CLLocationCoordinate2D>()
        let authorizationStatus = PublishSubject<CLAuthorizationStatus>()
        let weatherData = PublishRelay<WeatherModel>()

        input.locationButton
            .withUnretained(self)
            .flatMapLatest { owner, _ -> Single<Result<WeatherModel, AFError>> in
                let status = owner.locationManager.authorizationStatus

                switch status {
                case .notDetermined:
                    owner.locationManager.desiredAccuracy = kCLLocationAccuracyBest
                    owner.locationManager.requestWhenInUseAuthorization()
                    return .never()
                case .authorizedWhenInUse:
                    owner.locationManager.startUpdatingLocation()
                    guard let coordinate = owner.locationManager.location?.coordinate else { return .never() }

                    currentLocation.accept(coordinate)
                    state.savedLocation = coordinate

                    return owner.fetchData(lat: coordinate.latitude.description, lon: coordinate.longitude.description)
                case .denied:
                    let coordinate = owner.defaultLocation
                    currentLocation.accept(coordinate)
                    state.savedLocation = coordinate
                    return owner.fetchData(lat: coordinate.latitude.description, lon: coordinate.longitude.description)
                default:
                    return .never()
                }
            }
            .bind(with: self) { owner, value in
                switch value {
                case .success(let data):
                    weatherData.accept(data)
                case .failure(let error):
                    print(error)
                }
            }
            .disposed(by: disposeBag)

        input.refreshButton
            .withUnretained(self)
            .flatMap { owner, _ in
                return owner.fetchData(lat: state.savedLocation.latitude.description, lon: state.savedLocation.longitude.description)
            }
            .bind(with: self) { owner, value in
                switch value {
                case .success(let data):
                    weatherData.accept(data)
                case .failure(let error):
                    print(error)
                }
            }
            .disposed(by: disposeBag)

        input.authorizationChanged
            .withUnretained(self)
            .flatMap { owner, status -> Single<Result<WeatherModel, AFError>> in
                switch status {
                case .authorizedWhenInUse, .authorizedAlways:
                    guard let coordinate = owner.locationManager.location?.coordinate else { return .never() }

                    currentLocation.accept(coordinate)
                    return owner.fetchData(lat: coordinate.latitude.description, lon: coordinate.longitude.description)
                case .denied:
                    let coordinate = owner.defaultLocation
                    currentLocation.accept(owner.defaultLocation)
                    return owner.fetchData(lat: coordinate.latitude.description, lon: coordinate.longitude.description)
                default:
                    return .never()
                }
            }
            .bind(with: self) { owner, value in
                switch value {
                case .success(let data):
                    weatherData.accept(data)
                case .failure(let error):
                    print(error)
                }
            }
            .disposed(by: disposeBag)

        input.authorizationChanged
            .bind(with: self) { owner, status in
                switch status {
                case .authorizedWhenInUse, .authorizedAlways:
                    guard let coordinate = owner.locationManager.location?.coordinate else { return }

                    currentLocation.accept(coordinate)
                    owner.fetchData(lat: coordinate.latitude.description, lon: coordinate.longitude.description, completionHandler: { responseData in
                        switch responseData {
                        case .success(let data):
                            weatherData.accept(data)
                        case .failure(let error):
                            print(error)
                        }
                    })
                case .denied:
                    currentLocation.accept(owner.defaultLocation)
                    owner.fetchData(lat: owner.defaultLocation.latitude.description, lon: owner.defaultLocation.longitude.description) { responseData in
                        switch responseData {
                        case .success(let data):
                            weatherData.accept(data)
                        case .failure(let error):
                            print(error)
                        }
                    }
                default:
                    print(status)
                }

                authorizationStatus.onNext(status)
            }
            .disposed(by: disposeBag)

        return Output(currentLocation: currentLocation, authorizationStatus: authorizationStatus, weatherData: weatherData)
    }

    private func fetchData(lat: String, lon: String, completionHandler: @escaping (Result<WeatherModel, AFError>) -> ()) {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "API_KEY") as? String else { return }
        guard let url = URL(string: "https://api.openweathermap.org/data/2.5/weather?lat=\(lat)&lon=\(lon)&appid=\(key)&units=metric") else { return }
        AF.request(url)
            .validate()
            .responseDecodable(of: WeatherModel.self) { responseData in
                switch responseData.result {
                case .success(let data):
                    completionHandler(.success(data))
                case .failure(let error):
                    completionHandler(.failure(error))
                }
            }
    }

    private func fetchData(lat: String, lon: String) -> Single<Result<WeatherModel, AFError>> {

        guard let key = Bundle.main.object(forInfoDictionaryKey: "API_KEY") as? String else { return .never() }

        return Single.create { value in
            if let url = URL(string: "https://api.openweathermap.org/data/2.5/weather?lat=\(lat)&lon=\(lon)&appid=\(key)&units=metric") {
                AF.request(url)
                    .validate()
                    .responseDecodable(of: WeatherModel.self) { responseData in
                        switch responseData.result {
                        case .success(let data):
                            value(.success(.success(data)))
                        case .failure(let error):
                            value(.success(.failure(error)))
                        }
                    }
            }
            return Disposables.create()
        }
    }
}
