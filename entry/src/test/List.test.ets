import localUnitTest from './LocalUnit.test';
import kdbxUtilsUnitTest from './KdbxUtilsUnit.test';
import byteUtilsUnitTest from './ByteUtilsUnit.test';
import kdbxConstantsUnitTest from './KdbxConstantsUnit.test';
import passwordGeneratorUnitTest from './PasswordGeneratorUnit.test';
import databaseDisplayUtilUnitTest from './DatabaseDisplayUtilUnit.test';
import entryServiceUnitTest from './EntryServiceUnit.test';
import dirtyFlagUnitTest from './DirtyFlagUnit.test';
import searchHelperUnitTest from './SearchHelperUnit.test';

export default function testsuite() {
  localUnitTest();
  kdbxUtilsUnitTest();
  byteUtilsUnitTest();
  kdbxConstantsUnitTest();
  passwordGeneratorUnitTest();
  databaseDisplayUtilUnitTest();
  entryServiceUnitTest();
  dirtyFlagUnitTest();
  searchHelperUnitTest();
}