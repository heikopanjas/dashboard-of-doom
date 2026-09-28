import Foundation
import Testing

@Suite struct SurveyStateTests {
    @Test func aDistrictKeyNamesItsState() {
        // Passau, Koblenz, Dithmarschen and a Berlin Bezirk.
        #expect(SurveyController.federalState(forDistrict: "09262") == "Bayern")
        #expect(SurveyController.federalState(forDistrict: "07111") == "Rheinland-Pfalz")
        #expect(SurveyController.federalState(forDistrict: "01051") == "Schleswig-Holstein")
        #expect(SurveyController.federalState(forDistrict: "11001") == "Berlin")
        #expect(SurveyController.federalState(forDistrict: "17000") == nil)
        #expect(SurveyController.federalStates.count == 16)
    }

    @Test func aStateFindsItsParliamentByDAWUMsShortcut() {
        #expect(SurveyController.parliament("Bayern", isFor: "Bayern") == true)
        #expect(SurveyController.parliament("Nordrhein-Westfalen (NRW)", isFor: "Nordrhein-Westfalen") == true)
        // Saxony is not Saxony-Anhalt, and the Bundestag is no state's.
        #expect(SurveyController.parliament("Sachsen-Anhalt", isFor: "Sachsen") == false)
        #expect(SurveyController.parliament("Bundestag", isFor: "Berlin") == false)
    }
}
