import FocusPersistence
import Testing

@Test
func moduleNameIsFocusPersistence() {
  #expect(FocusPersistenceModule.moduleName == "FocusPersistence")
}

@Test
func sqliteIsLinked() {
  #expect(FocusPersistenceModule.sqliteLinked)
}
