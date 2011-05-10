Feature: Store and load data for classes with inheritence relation
  Background:
    Given the library works in development mode

  Scenario: two classes: A and B < A, sharing some fields,
      connected to the same database.

    Given the class space is cleared
    And a class Person inherits from Rod::Model
    And a class Person has a name field of type string
    And a class Person is connected to Database1
    And a class User inherits from Person
    And a class User has a login field of type string
    When Database1 is created
    And I create a Person
    And his name is 'John'
    And I store him in the database
    And I create a User
    And her name is 'Annie'
    And her login is 'ann123'
    And I store her in the database
    And I reopen Database1 for reading
    Then there should be 1 Person(s)
    And the name of the first Person should be 'John'
    And there should be 1 User
    And the name of the first User should be 'Annie'
    And the login of the first User should be 'ann123'

  Scenario: three classes: A, B < A and C < D sharing some fields,
      connected to the same database.

    Given the class space is cleared
    And a class Person inherits from Rod::Model
    And a class Person has a name field of type string
    And a class Person is connected to Database1
    And a class User inherits from Person
    And a class User has a login field of type string
    And a class SuperUser inherits from User
    And a class SuperUser has a room field of type string
    When Database1 is created
    And I create a Person
    And his name is 'John'
    And I store him in the database
    And I create a User
    And her name is 'Annie'
    And her login is 'ann123'
    And I store her in the database
    And I create a SuperUser
    And his name is 'Nerd'
    And his login is 'n4rrd'
    And his room is '2-111'
    And I store him in the database
    And I reopen Database1 for reading
    Then there should be 1 Person(s)
    And there should be 1 User(s)
    And there should be 1 SuperUser
    And the name of the first Person should be 'John'
    And the name of the first User should be 'Annie'
    And the login of the first User should be 'ann123'
    And the name of the first SuperUser should be 'Nerd'
    And the login of the first SuperUser should be 'n4rrd'
    And the room of the first SuperUser should be '2-111'
