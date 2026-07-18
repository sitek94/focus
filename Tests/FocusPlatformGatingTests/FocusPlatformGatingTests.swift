import FocusControl
import FocusPersistence
import FocusSession
import Testing

@Test
func portableModulesAreAvailable() {
  #expect(FocusSessionModule.moduleName == "FocusSession")
  #expect(FocusControlModule.moduleName == "FocusControl")
  #expect(FocusPersistenceModule.moduleName == "FocusPersistence")
}
