Feature: model as a collection of objects
  In order to fullfil its design goals, Rod should allow to store large
  numbers of objects and faciliate their retrieval.

  Background:
    Given the library works in development mode

  Scenario: enumerator behavior
      The model should provide enumerator behavior (each, find, select, etc.).
    Given the class space is cleared
    And the model is connected with the default database
    And a class User has a name field of type string
    And a class User has a surname field of type string
    And a class User has a login field of type string
    And a class User has an age field of type integer
    When database is created
    And I create and store the following User(s):
      | name | surname | login | age  |
      | John | Smith   | john  | 12   |
      | Lara | Croft   | lara  | 23   |
      | Adam | Parker  | adam  | 17   |
    And I reopen database for reading
    Then there should be 3 User
    And I should be able to iterate over these User(s)
    And I should be able to iterate with index over these User(s)
    And I should be able to find a User with '12' age and 'john' login
    And there should be 2 User(s) with age below 20
    And there should be 1 User with age below 20 with index below 2
