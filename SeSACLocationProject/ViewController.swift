//
//  ViewController.swift
//  SeSACLocation
//
//  Created by Lee on 9/9/25.
//

import UIKit
import SnapKit
import CoreLocation
import RxSwift
import RxCocoa
import MapKit
import Alamofire

final class ViewController: UIViewController {

    let mapView = MKMapView()

    let disposeBag = DisposeBag()

    let defaultLocation = CLLocationCoordinate2D(latitude: 37.519485, longitude: 126.890398)

    private let locationButton: UIButton = {
        let button = UIButton()
        button.layer.cornerRadius = 25
        button.backgroundColor = .white
        button.clipsToBounds = true
        button.layer.borderColor = UIColor.lightGray.cgColor
        button.layer.borderWidth = 2
        button.setImage(UIImage(systemName: "location.fill"), for: .normal)
        return button
    }()

    private let refreshButton: UIButton = {
        let button = UIButton()
        button.layer.cornerRadius = 25
        button.backgroundColor = .white
        button.clipsToBounds = true
        button.layer.borderColor = UIColor.lightGray.cgColor
        button.layer.borderWidth = 2
        button.setImage(UIImage(systemName: "arrow.clockwise"), for: .normal)
        return button
    }()

    private let resultLabel: UILabel = {
        let label = UILabel()
        label.text = "날씨 정보를 불러오는 중..."
        label.textColor = .black
        label.font = .systemFont(ofSize: 14)
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    private let locationManager = CLLocationManager()

    override func viewDidLoad() {
        super.viewDidLoad()

        configureHierarchy()
        configureLayout()
        configureView()
        bind()

        locationManager.delegate = self
    }

    private func configureHierarchy() {
        [locationButton, refreshButton, resultLabel].forEach { view.addSubview($0) }

        view.addSubview(mapView)
    }

    private func configureLayout() {
        locationButton.snp.makeConstraints { make in
            make.size.equalTo(50)
            make.leading.bottom.equalTo(view.safeAreaLayoutGuide).inset(30)
        }

        refreshButton.snp.makeConstraints { make in
            make.size.equalTo(50)
            make.trailing.bottom.equalTo(view.safeAreaLayoutGuide).inset(30)
        }

        mapView.snp.makeConstraints { make in
            make.top.horizontalEdges.equalToSuperview()
            make.height.equalTo(460)
        }

        resultLabel.snp.makeConstraints { make in
            make.top.equalTo(mapView.snp.bottom).offset(20)
            make.centerX.equalToSuperview()
        }
    }

    private func configureView() {
        view.backgroundColor = .white
    }

    private func bind() {
        locationButton.rx.tap
            .bind(with: self) { owner, _ in
                owner.checkLocation()
            }
            .disposed(by: disposeBag)

        refreshButton.rx.tap
            .bind(with: self) { owner, _ in
                let coordinate = owner.defaultLocation
                owner.fetchData(lat: coordinate.latitude.description, lon: coordinate.longitude.description) { responseData in
                    switch responseData {
                    case .success(let data):
                        let date = Date()
                        let dateStr = DateManager.changeDateForString(date: date)
                        self.resultLabel.text = """
                        \(dateStr)
                        현재온도: \(data.main.temp)°C
                        최저: \(data.main.tempMin) / 최고 \(data.main.tempMax) 
                        풍속: \(data.wind.speed)m/s
                        습도: \(data.main.humidity)%
                        """
                    case .failure(let error):
                        print(error)
                    }
                }
            }
            .disposed(by: disposeBag)
    }

    private func checkLocation() {
        DispatchQueue.global().async {
            if CLLocationManager.locationServicesEnabled() {
                print("권한 사용이 가능한 상태")

                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.checkCurrentLocationAuthorization()
                }
            } else {
                print("위치 권한이 꺼져있어서 위치 권한을 요청할 수 없습니다")
            }
        }
    }

    private func checkCurrentLocationAuthorization() {

        var status: CLAuthorizationStatus

        if #available(iOS 14.0, *) {
            status = locationManager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }

        switch status {
        case .notDetermined:
            print("아직 위치 권한에 대한 결정이 안된 상태")
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.requestWhenInUseAuthorization()
        case .denied:
            print("권한 거부됨")

            let region = MKCoordinateRegion(center: defaultLocation, latitudinalMeters: 500, longitudinalMeters: 500)
            mapView.setRegion(region, animated: true)

            showLocationSettingAlert()

            makeAnnotation(lat: defaultLocation.latitude, lon: defaultLocation.longitude)

            fetchData(lat: defaultLocation.latitude.description, lon: defaultLocation.longitude.description) { [weak self] responseData in
                guard let self else { return }
                switch responseData {
                case .success(let data):
                    let date = Date()
                    let dateStr = DateManager.changeDateForString(date: date)
                    self.resultLabel.text = """
                    \(dateStr)
                    현재온도: \(data.main.temp)°C
                    최저: \(data.main.tempMin) / 최고 \(data.main.tempMax) 
                    풍속: \(data.wind.speed)m/s
                    습도: \(data.main.humidity)%
                    """
                case .failure(let error):
                    print(error)
                }
            }

        case .authorizedWhenInUse:
            print("사용하는 동안 허용한 상태")
            locationManager.startUpdatingLocation()

            guard let coordinate = locationManager.location?.coordinate else { return }

            let region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 500, longitudinalMeters: 500)
            mapView.setRegion(region, animated: true)

            makeAnnotation(lat: coordinate.latitude, lon: coordinate.longitude)

            fetchData(lat: coordinate.latitude.description, lon: coordinate.longitude.description) { [weak self] responseData in
                guard let self else { return }
                switch responseData {
                case .success(let data):
                    let date = Date()
                    let dateStr = DateManager.changeDateForString(date: date)
                    self.resultLabel.text = """
                        \(dateStr)
                        현재온도: \(data.main.temp)°C
                        최저: \(data.main.tempMin) / 최고 \(data.main.tempMax)  
                        풍속: \(data.wind.speed)m/s
                        습도: \(data.main.humidity)%
                        """
                case .failure(let error):
                    print(error)
                }
            }

        default:
            print(status)
        }
    }

    private func showLocationSettingAlert() {
        let alert = UIAlertController(title: "위치 정보", message: "위치 정보를 이용하려면 권한에 대한 설정이 필요합니다. 기기의 '설정 > 개인정보 보호에서 위치 서비스를 켜주세요'", preferredStyle: .alert)
        let goSetting = UIAlertAction(title: "설정으로 이동", style: .default) { _ in
            if let setting = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(setting)
            }
        }

        let cancel = UIAlertAction(title: "취소", style: .cancel)
        alert.addAction(goSetting)
        alert.addAction(cancel)
        present(alert, animated: true)
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

    private func makeAnnotation(lat: CLLocationDegrees, lon: CLLocationDegrees) {
        let annotation = MKPointAnnotation()
        annotation.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        mapView.addAnnotation(annotation)
    }
}

extension ViewController: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print(#function)
    }


    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        print(#function)
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print(#function)
    }
}

