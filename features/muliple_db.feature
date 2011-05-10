Feature: Store and load data from multiple databases

  Background:
    Given the library works in development mode

  Scenario: two classes with two dbs
    Given the class space is cleared
    And a class Caveman inherits from Rod::Model
    And a class Caveman has a name field of type string
    And a class Caveman is connected to Database1
    And a class Automobile inherits from Rod::Model
    And a class Automobile has a name field of type string
    And a class Automobile is connected to Database2
    When Database1 is created
    And Database2 is created
    And I create a Caveman 
    And his name is 'Fred'
    And I store him in the database
    And I create an Automobile 
    And its name is 'Prehistoric'
    And I store him in the database
    And I reopen Database1 for reading
    And I reopen Database2 for reading
    Then there should be 1 Caveman
    And the name of the first Caveman should be 'Fred'
    And there should be 1 Automobile
    And the name of the first Automobile should be 'Prehistoric'

  Scenario: three classes with two dbs and consistent hierarchy
      A connected to DB1
      B < A connected to DB2
      C < B connected to DB2

    Given the class space is cleared
    And a class Person inherits from Rod::Model
    And a class Person has a name field of type string
    And a class Person is connected to Database1
    And a class User inherits from Person
    And a class User has a login field of type string
    And a class User is connected to Database2
    And a class SuperUser inherits from User
    And a class SuperUser has a room field of type string
    When Database1 is created
    And Database2 is created
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
    And I reopen Database2 for reading
    Then there should be 1 Person(s)
    And there should be 1 User(s)
    And there should be 1 SuperUser
    And the name of the first Person should be 'John'
    And the first Person should not have a login field
    And the first Person should not have a room field
    And the name of the first User should be 'Annie'
    And the login of the first User should be 'ann123'
    And the first User should not have a room field
    And the name of the first SuperUser should be 'Nerd'
    And the login of the first SuperUser should be 'n4rrd'
    And the room of the first SuperUser should be '2-111'

  Scenario: three classes with two dbs and consistent hierarchy:
      A connected to DB1
      B < A connected to DB2
      C < B connected to DB1

    Given the class space is cleared
    And a class Person inherits from Rod::Model
    And a class Person has a name field of type string
    And a class Person is connected to Database1
    And a class User inherits from Person
    And a class User has a login field of type string
    And a class SuperUser inherits from User
    And a class SuperUser has a room field of type string
    And a class User is connected to Database2
    When Database1 is created
    And Database2 is created
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
    And I reopen Database2 for reading
    Then there should be 1 Person(s)
    And there should be 1 User(s)
    And there should be 1 SuperUser
    And the name of the first Person should be 'John'
    And the first Person should not have a login field
    And the first Person should not have a room field
    And the name of the first User should be 'Annie'
    And the login of the first User should be 'ann123'
    And the first User should not have a room field
    And the name of the first SuperUser should be 'Nerd'
    And the login of the first SuperUser should be 'n4rrd'
    And the room of the first SuperUser should be '2-111'
