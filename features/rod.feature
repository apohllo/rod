Feature: ROD Storage
  In order to persist data
  Potential users
  Must be able to store and load their objects.

  Scenario Outline: Store and load Fred
    Given database is opened for writing
      And Fred is <init_age> years old
    When  I store Fred
      And Fred is <grown_age> years old now
      And I reopen database for reading
      And I restore Fred
    Then  database should be opened for reading
      And Fred should be <init_age> years old again

    Examples:
      | init_age  | grown_age |
      | 2         | 3         |
      | 8         | 28        |

  Scenario Outline: Store a few Freds of different sexes. Count restored by sex.
    Given database is opened for writing
      And first Fred is <sex1>
      And second Fred is <sex2>
      And thrid Fred is <sex3>
    When  I store all Freds
      And I reopen database for reading
    Then  database should be opened for reading
      And database should contain <count1> male Freds
      And database should contain <count2> female Freds

    Examples:
      | sex1  | sex2  | sex3    | count1  | count2  | 
      | female| male  | female  | 1       | 2       |
      | male  | male  | female  | 2       | 1       |
