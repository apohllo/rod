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
    Then there should be 3 User(s)
    And I should be able to iterate over these User(s)
    And I should be able to iterate with index over these User(s)
    And I should be able to find a User with '12' age and 'john' login
    And there should be 2 User(s) with age below 20
    And there should be 1 User with age below 20 with index below 2

  Scenario: multiple object
      The database should properly store thousands of objects.
    Given the class space is cleared
    And the model is connected with the default database
    And a class User has a name field of type string
    And a class User has a surname field of type string
    And a class User has an age field of type integer
    When database is created
    And I create a User
    And his name is 'John'
    And his surname is 'Smith'
    And his age is '21'
    And I store him in the database 1000 times
    And I create a User
    And her name is 'Lara'
    And her surname is 'Croft'
    And her age is '23'
    And I store her in the database 1000 times
    And I reopen database for reading
    Then there should be 2000 User(s)
    Then User(s) from 1 to 1000 should have 'John' name
    Then User(s) from 1001 to 2000 should have 'Lara' name

  Scenario: multiple object with indexed fields
      The database should properly store thausands of objects with some indexed fields.
    Given the class space is cleared
    And the model is connected with the default database
    And a class User has a name field of type string with flat index
    And a class User has a surname field of type string with flat index
    And a class User has an age field of type integer
    When database is created
    And I create a User
    And his name is 'John'
    And his surname is 'Smith'
    And his age is '21'
    And I store him in the database 1000 times
    And I create a User
    And her name is 'Lara'
    And her surname is 'Croft'
    And her age is '23'
    And I store her in the database 1000 times
    And I reopen database for reading
    Then there should be 2000 User(s)
    Then there should be 1000 User(s) with 'John' name
    Then there should be 1000 User(s) with 'Smith' surname
    Then there should be 1000 User(s) with 'Lara' name
    Then there should be 1000 User(s) with 'Croft' surname

  Scenario: multiple object with has one relationship
      The database should properly store thousands of objects with has many relationship.
    Given the class space is cleared
    And the model is connected with the default database
    And a class Automobile has a name field of type string 
    And a class User has a name field of type string
    And a class User has a surname field of type string
    And a class User has an age field of type integer
    And a class User has one automobile
    When database is created
    And I create an Automobile
    And its name is 'Modern car'
    And I store it in the database
    And I create a User
    And his name is 'John'
    And his surname is 'Smith'
    And his age is '21'
    And his automobile is the first Automobile created
    And I store him in the database 1000 times
    And I reopen database for reading
    Then there should be 1000 User(s)
    Then User(s) from 1 to 1000 should have an automobile equal to the first Automobile

  Scenario: multiple object with has many relationship
      The database should properly store thousands of objects with has many relationship.
    Given the class space is cleared
    And the model is connected with the default database
    And a class Automobile has a name field of type string 
    And a class User has a name field of type string
    And a class User has a surname field of type string
    And a class User has an age field of type integer
    And a class User has many automobiles
    When database is created
    And I create an Automobile
    And its name is 'Prehistoric car'
    And I store it in the database
    And I create another Automobile
    And its name is 'Modern car'
    And I store it in the database
    And I create a User
    And his name is 'John'
    And his surname is 'Smith'
    And his age is '21'
    And his automobiles contain the first Automobile created
    And his automobiles contain the second Automobile created
    And I store him in the database 1000 times
    Then User(s) from 1 to 1000 should have 2 automobiles
    And User(s) from 1 to 1000 should have first of automobiles equal to the first Automobile created
    And User(s) from 1 to 1000 should have second of automobiles equal to the second Automobile created
