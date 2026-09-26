import SwiftUI

/// Every source the app uses with the credit its licence asks for, the Apple Weather attribution first. Both About screens show it; the
/// platforms only frame it differently.
struct DataSourceList: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Weather")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                WeatherAttributionView()
            }
            ForEach(DataSources.all()) { source in
                VStack(alignment: .leading, spacing: 2) {
                    Text(source.topic)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(source.attribution)
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 12) {
                        if let licence = source.licence {
                            if let url = source.licenceURL {
                                Link(licence, destination: url)
                            }
                            else {
                                Text(licence)
                            }
                        }
                        if let url = source.sourceURL, let host = url.host() {
                            Link(host, destination: url)
                        }
                    }
                    .font(.caption)
                }
                .foregroundStyle(.primary)
            }
        }
    }
}
