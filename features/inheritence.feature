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
    And the first Person should not have a login field
    And there should be 1 User
    And the name of the first User should be 'Annie'
    And the login of the first User should be 'ann123'

  Scenario: three classes: A, B < A and C < B sharing some fields,
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
    And the first Person should not have a login field
    And the first Person should not have a room field
    And the name of the first User should be 'Annie'
    And the login of the first User should be 'ann123'
    And the first User should not have a room field
    And the name of the first SuperUser should be 'Nerd'
    And the login of the first SuperUser should be 'n4rrd'
    And the room of the first SuperUser should be '2-111'

  Scenario: two classes: A and B < A, sharing some fields and has one relations,
      connected to the same database.

    Given the class space is cleared
    And a class Automobile inherits from Rod::Model
    And a class Automobile has a name field of type string
    And a class Automobile is connected to Database1
    And a class Dog inherits from Rod::Model
    And a class Dog has a name field of type string
    And a class Dog is connected to Database1
    And a class Account inherits from Rod::Model
    And a class Account has a id field of type integer
    And a class Account is connected to Database1
    And a class Person inherits from Rod::Model
    And a class Person has a name field of type string
    And a class Person has one automobile
    And a class Person has one dog
    And a class Person is connected to Database1
    And a class User inherits from Person
    And a class User has a login field of type string
    And a class User has one account
    When Database1 is created
    And I create an Automobile
    And its name is 'Modern'
    And I store it in the database
    And I create a Dog
    And its name is 'Snoopy'
    And I store it in the database
    And I create an Account
    And its id is '100'
    And I store it in the database
    And I create a Person
    And his name is 'John'
    And I store him in the database
    And I create a User
    And her name is 'Annie'
    And her login is 'ann123'
    And her automobile is the first Automobile created
    And her dog is the first Dog created
    And her account is the first Account created
    And I store her in the database
    And I reopen Database1 for reading
    Then there should be 1 Person
    And the name of the first Person should be 'John'
    And the first Person should not have an Account
    And there should be 1 User
    And the name of the first User should be 'Annie'
    And the login of the first User should be 'ann123'
    And the automobile of the first User should be equal to the first Automobile
    And the dog of the first User should be equal to the first Dog
    And the account of the first User should be equal to the first Account

  Scenario: two classes: A and B < A, sharing some fields and has many relations,
      connected to the same database.

    Given the class space is cleared
    And a class Automobile inherits from Rod::Model
    And a class Automobile has a name field of type string
    And a class Automobile is connected to Database1
    And a class Dog inherits from Rod::Model
    And a class Dog has a name field of type string
    And a class Dog is connected to Database1
    And a class Account inherits from Rod::Model
    And a class Account has a id field of type integer
    And a class Account is connected to Database1
    And a class Person inherits from Rod::Model
    And a class Person has a name field of type string
    And a class Person has many automobiles
    And a class Person has many dogs
    And a class Person is connected to Database1
    And a class User inherits from Person
    And a class User has a login field of type string
    And a class User has many accounts
    When Database1 is created
    And I create an Automobile
    And its name is 'Modern'
    And I store him in the database
    And I create another Automobile
    And its name is 'Prehistoric'
    And I store him in the database
    And I create a Dog
    And its name is 'Snoopy'
    And I store it in the database
    And I create a Dog
    And its name is 'Pluto'
    And I store it in the database
    And I create an Account
    And its id is '100'
    And I store it in the database
    And I create an Account
    And its id is '200'
    And I store it in the database
    And I create a Person
    And his name is 'John'
    And I store him in the database
    And I create a User
    And her name is 'Annie'
    And her login is 'ann123'
    And her automobiles contain the first Automobile created
    And her automobiles contain the second Automobile created
    And her dogs contain the first Dog created
    And her dogs contain the second Dog created
    And her accounts contain the first Account created
    And her accounts contain the second Account created
    And I store her in the database
    And I reopen Database1 for reading
    Then there should be 1 Person
    And the name of the first Person should be 'John'
    And the first Person should not have an Account
    And there should be 1 User
    And the name of the first User should be 'Annie'
    And the login of the first User should be 'ann123'
    And the first User should have 2 automobiles
    And the first User should have 2 dogs
    And the first User should have 2 accounts
    And the first of automobiles of the first User should be equal to the first Automobile
    And the second of automobiles of the first User should be equal to the second Automobile
    And the first of dogs of the first User should be equal to the first Dog
    And the second of dogs of the first User should be equal to the second Dog
    And the first of accounts of the first User should be equal to the first Account
    And the second of accounts of the first User should be equal to the second Account
