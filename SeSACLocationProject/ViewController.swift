//
//  ViewController.swift
//  SeSACLocation
//
//  Created by Lee on 9/9/25.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa
import MapKit
import CoreLocation

final class ViewController: UIViewController {

    let viewModel = LocationViewModel()

    let mapView = MKMapView()

    let disposeBag = DisposeBag()

    private let authorizationChanged = PublishRelay<CLAuthorizationStatus>()

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

        let input = LocationViewModel.Input(locationButton: locationButton.rx.tap, refreshButton: refreshButton.rx.tap, authorizationChanged: authorizationChanged.asObservable())

        let output = viewModel.transform(input: input)

        output.weatherData
            .map {
                let date = Date()
                let dateStr = DateManager.changeDateForString(date: date)
                return """
                \(dateStr)
                현재온도: \($0.main.temp)°C
                최저: \($0.main.tempMin) / 최고 \($0.main.tempMax)
                풍속: \($0.wind.speed)m/s
                습도: \($0.main.humidity)%
                """
            }
            .bind(to: resultLabel.rx.text)
            .disposed(by: disposeBag)

        Observable.combineLatest(output.currentLocation, output.authorizationStatus)
            .bind(with: self) { owner, value in
                let (location, status) = value
                switch status {
                case .notDetermined:
                    print("아직 결정이 안된 상태")
                case .authorizedWhenInUse:
                    owner.setRegionAndAnnotation(center: location)
                case .denied:
                    owner.setRegionAndAnnotation(center: location)
                    owner.showLocationSettingAlert()
                default:
                    print(status)
                }
            }
            .disposed(by: disposeBag)
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

    private func setRegionAndAnnotation(center: CLLocationCoordinate2D) {
        let region = MKCoordinateRegion(center: center, latitudinalMeters: 500, longitudinalMeters: 500)
        mapView.setRegion(region, animated: true)
        makeAnnotation(lat: center.latitude, lon: center.longitude)
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
        authorizationChanged.accept(manager.authorizationStatus)
        print(#function)
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print(#function)
        authorizationChanged.accept(status)
    }
}

